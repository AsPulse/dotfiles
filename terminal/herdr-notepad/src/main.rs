use base64::{Engine as _, engine::general_purpose::STANDARD as BASE64};
use serde_json::{Value, json};
use signal_hook::consts::{SIGHUP, SIGINT, SIGTERM};
use signal_hook::flag as signal_flag;
use std::env;
use std::ffi::{OsStr, OsString};
use std::fs;
use std::io::{self, Read, Write};
use std::os::unix::ffi::{OsStrExt, OsStringExt};
use std::os::unix::net::UnixStream;
use std::os::unix::process::{CommandExt, ExitStatusExt};
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode, Stdio};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::Duration;
use tempfile::{Builder as TempBuilder, NamedTempFile, TempDir};

const TARGET_HEIGHT: u32 = 10;
const MIN_REMAINING: u32 = 3;
const STATUS_POLL: Duration = Duration::from_millis(50);

fn main() -> ExitCode {
    match run() {
        Ok(code) => exit_code_from_i32(code),
        Err(err) => {
            let _ = writeln!(io::stderr(), "herdr-notepad: {err}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<i32, String> {
    if env::var_os("HERDR_NOTEPAD_CHILD").as_deref() == Some(OsStr::new("1")) {
        return run_child_mode();
    }

    let nvim_args: Vec<OsString> = env::args_os().skip(1).collect();

    if env::var_os("HERDR_ENV").as_deref() != Some(OsStr::new("1")) {
        exec_nvim(&nvim_args);
    }

    run_herdr_parent(&nvim_args)
}

fn run_child_mode() -> Result<i32, String> {
    let status_file =
        env::var("HERDR_NOTEPAD_STATUS").map_err(|_| "missing child-mode env".to_string())?;
    let args_b64 =
        env::var("HERDR_NOTEPAD_ARGS_B64").map_err(|_| "missing child-mode env".to_string())?;

    let nvim_args = match decode_args_payload(&args_b64) {
        Ok(args) => args,
        Err(err) => {
            let _ = write_status(&status_file, 1);
            return Err(err);
        }
    };

    let status = Command::new(nvim_bin())
        .args(&nvim_args)
        .status()
        .map_err(|err| format!("failed to run nvim: {err}"))?;

    let code = exit_status_to_code(status);
    write_status(&status_file, code)?;
    Ok(code)
}

fn run_herdr_parent(nvim_args: &[OsString]) -> Result<i32, String> {
    let herdr = herdr_bin();
    if !herdr_available(&herdr) {
        exec_nvim(nvim_args);
    }

    let caller = match caller_pane_id(&herdr) {
        Ok(id) => id,
        Err(_) => exec_nvim(nvim_args),
    };

    let height = match caller_height(&herdr, &caller) {
        Ok(h) => h,
        Err(_) => exec_nvim(nvim_args),
    };

    let Some(ratio) = split_ratio(height) else {
        exec_nvim(nvim_args);
    };

    let self_exe = current_exe_path()?;
    let args_b64 = encode_args_payload(nvim_args)?;

    let tmp_dir = TempBuilder::new()
        .prefix("herdr-notepad.")
        .tempdir()
        .map_err(|err| format!("failed to create temp dir: {err}"))?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(tmp_dir.path())
            .map_err(|err| format!("failed to stat temp dir: {err}"))?
            .permissions();
        perms.set_mode(0o700);
        fs::set_permissions(tmp_dir.path(), perms)
            .map_err(|err| format!("failed to chmod temp dir: {err}"))?;
    }
    let status_file = tmp_dir.path().join("status");

    let terminate = Arc::new(AtomicBool::new(false));
    for sig in [SIGINT, SIGTERM, SIGHUP] {
        signal_flag::register(sig, Arc::clone(&terminate))
            .map_err(|err| format!("failed to register signal handler: {err}"))?;
    }

    let mut cleanup = CleanupGuard {
        herdr: herdr.clone(),
        pane_id: None,
        caller_pane_id: Some(caller.clone()),
        _tmp_dir: Some(tmp_dir),
    };

    let ratio_str = format!("{ratio:.6}");
    let status_env = format!("HERDR_NOTEPAD_STATUS={}", status_file.display());
    let args_env = format!("HERDR_NOTEPAD_ARGS_B64={args_b64}");
    let nvim_override = env::var("HERDR_NOTEPAD_NVIM").ok();
    let nvim_env = nvim_override
        .as_ref()
        .map(|path| format!("HERDR_NOTEPAD_NVIM={path}"));

    let mut split_args: Vec<&str> = vec![
        "pane",
        "split",
        &caller,
        "--direction",
        "down",
        "--ratio",
        &ratio_str,
        "--focus",
        "--env",
        "HERDR_NOTEPAD_CHILD=1",
        "--env",
        &status_env,
        "--env",
        &args_env,
    ];
    if let Some(ref nvim_env) = nvim_env {
        split_args.push("--env");
        split_args.push(nvim_env);
    }

    let split_output = match run_herdr_capture(&herdr, &split_args) {
        Ok(stdout) => stdout,
        Err(_) => {
            cleanup.disarm();
            exec_nvim(nvim_args);
        }
    };

    let new_pane_id = match parse_pane_id(&split_output) {
        Ok(id) => id,
        Err(_) => {
            cleanup.disarm();
            exec_nvim(nvim_args);
        }
    };
    cleanup.pane_id = Some(new_pane_id.clone());

    let run_cmd = format!("exec {}", posix_shell_quote(&self_exe));
    if run_herdr_quiet(&herdr, &["pane", "run", &new_pane_id, &run_cmd]).is_err() {
        // Pane already created: clean up and fail instead of opening a second editor.
        return Err("failed to start editor in split pane".into());
    }

    let code = wait_for_status(&status_file, &herdr, &new_pane_id, &terminate)?;
    cleanup.finish();
    Ok(code)
}

struct CleanupGuard {
    herdr: PathBuf,
    pane_id: Option<String>,
    caller_pane_id: Option<String>,
    _tmp_dir: Option<TempDir>,
}

impl CleanupGuard {
    fn disarm(&mut self) {
        self.pane_id = None;
        self.caller_pane_id = None;
        self._tmp_dir = None;
    }

    fn finish(&mut self) {
        self.cleanup();
        self._tmp_dir = None;
    }

    fn cleanup(&mut self) {
        if let Some(pane_id) = self.pane_id.take() {
            let _ = run_herdr_quiet(&self.herdr, &["pane", "close", &pane_id]);
        }
        if let Some(caller_id) = self.caller_pane_id.take() {
            let _ = focus_pane(&caller_id);
        }
    }
}

impl Drop for CleanupGuard {
    fn drop(&mut self) {
        self.cleanup();
    }
}

fn herdr_bin() -> PathBuf {
    if let Ok(path) = env::var("HERDR_BIN_PATH") {
        return PathBuf::from(path);
    }
    if let Some(path) = option_env!("HERDR_BIN") {
        return PathBuf::from(path);
    }
    PathBuf::from("herdr")
}

fn nvim_bin() -> PathBuf {
    if let Ok(path) = env::var("HERDR_NOTEPAD_NVIM") {
        return PathBuf::from(path);
    }
    if let Some(path) = option_env!("NVIM_BIN") {
        return PathBuf::from(path);
    }
    PathBuf::from("nvim")
}

fn herdr_socket_path() -> PathBuf {
    if let Ok(path) = env::var("HERDR_SOCKET_PATH") {
        return PathBuf::from(path);
    }
    home_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".config/herdr/herdr.sock")
}

fn home_dir() -> Option<PathBuf> {
    env::var_os("HOME").map(PathBuf::from)
}

fn focus_pane(pane_id: &str) -> Result<(), String> {
    herdr_rpc("pane.focus", json!({ "pane_id": pane_id })).map(|_| ())
}

fn herdr_rpc(method: &str, params: Value) -> Result<Value, String> {
    let sock_path = herdr_socket_path();
    let mut stream = UnixStream::connect(&sock_path)
        .map_err(|err| format!("failed to connect to herdr socket: {err}"))?;

    let request = json!({
        "id": "herdr-notepad",
        "method": method,
        "params": params,
    });
    let mut payload = serde_json::to_vec(&request).map_err(|err| format!("encode rpc: {err}"))?;
    payload.push(b'\n');
    stream
        .write_all(&payload)
        .map_err(|err| format!("failed to send rpc: {err}"))?;

    let mut buf = Vec::new();
    let mut chunk = [0_u8; 65536];
    loop {
        let n = stream
            .read(&mut chunk)
            .map_err(|err| format!("failed to read rpc: {err}"))?;
        if n == 0 {
            break;
        }
        buf.extend_from_slice(&chunk[..n]);
        if buf.ends_with(b"\n") {
            break;
        }
    }

    if buf.is_empty() {
        return Err("empty RPC response".into());
    }

    let resp: Value =
        serde_json::from_slice(&buf).map_err(|err| format!("invalid rpc response: {err}"))?;
    if let Some(err) = resp.get("error") {
        return Err(err.to_string());
    }
    Ok(resp.get("result").cloned().unwrap_or(Value::Null))
}

fn herdr_available(herdr: &Path) -> bool {
    Command::new(herdr)
        .arg("--help")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn current_exe_path() -> Result<String, String> {
    let exe = env::current_exe().map_err(|err| format!("failed to resolve current exe: {err}"))?;
    exe.into_os_string()
        .into_string()
        .map_err(|_| "current exe path is not valid UTF-8".to_string())
}

fn exec_nvim(args: &[OsString]) -> ! {
    let err = Command::new(nvim_bin()).args(args).exec();
    let _ = writeln!(io::stderr(), "herdr-notepad: failed to exec nvim: {err}");
    std::process::exit(127);
}

fn caller_pane_id(herdr: &Path) -> Result<String, String> {
    if let Ok(id) = env::var("HERDR_PANE_ID")
        && !id.is_empty()
    {
        return Ok(id);
    }

    let stdout = run_herdr_capture(herdr, &["pane", "current", "--current"])?;
    parse_pane_id(&stdout)
}

fn caller_height(herdr: &Path, pane_id: &str) -> Result<u32, String> {
    if let Ok(stdout) = run_herdr_capture(herdr, &["pane", "layout", "--pane", pane_id])
        && let Ok(height) = parse_layout_height(&stdout, pane_id)
    {
        return Ok(height);
    }

    if let Ok(stdout) = run_herdr_capture(herdr, &["pane", "get", pane_id])
        && let Ok(height) = parse_viewport_rows(&stdout)
    {
        return Ok(height);
    }

    terminal_size::terminal_size()
        .map(|(_, h)| u32::from(h.0))
        .filter(|&h| h > 0)
        .ok_or_else(|| "unable to determine pane height".into())
}

fn split_ratio(height: u32) -> Option<f64> {
    if height < TARGET_HEIGHT + MIN_REMAINING {
        None
    } else {
        Some(f64::from(height - TARGET_HEIGHT) / f64::from(height))
    }
}

fn encode_args_payload(args: &[OsString]) -> Result<String, String> {
    let encoded: Vec<String> = args
        .iter()
        .map(|arg| BASE64.encode(arg.as_bytes()))
        .collect();
    let json = serde_json::to_string(&encoded).map_err(|err| format!("encode args: {err}"))?;
    Ok(BASE64.encode(json.as_bytes()))
}

fn decode_args_payload(payload_b64: &str) -> Result<Vec<OsString>, String> {
    let json_bytes = BASE64
        .decode(payload_b64.as_bytes())
        .map_err(|_| "invalid args payload (base64)".to_string())?;
    let encoded: Vec<String> = serde_json::from_slice(&json_bytes)
        .map_err(|_| "invalid args payload (json)".to_string())?;

    encoded
        .into_iter()
        .map(|item| {
            let bytes = BASE64
                .decode(item.as_bytes())
                .map_err(|_| "invalid args payload (arg base64)".to_string())?;
            Ok(OsString::from_vec(bytes))
        })
        .collect()
}

fn posix_shell_quote(value: &str) -> String {
    let mut out = String::from("'");
    for ch in value.chars() {
        if ch == '\'' {
            out.push_str("'\\''");
        } else {
            out.push(ch);
        }
    }
    out.push('\'');
    out
}

fn write_status(status_file: &str, code: i32) -> Result<(), String> {
    let path = Path::new(status_file);
    let dir = path
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let mut tmp = NamedTempFile::new_in(dir)
        .map_err(|err| format!("failed to create status temp file: {err}"))?;
    writeln!(tmp, "{code}").map_err(|err| format!("failed to write status: {err}"))?;
    tmp.persist(path)
        .map_err(|err| format!("failed to persist status: {err}"))?;
    Ok(())
}

fn parse_status(contents: &str) -> Result<i32, String> {
    let trimmed = contents.trim();
    if trimmed.is_empty() {
        return Err("empty exit status".into());
    }
    trimmed
        .parse::<i32>()
        .map_err(|_| format!("invalid exit status: {trimmed}"))
}

fn wait_for_status(
    status_file: &Path,
    herdr: &Path,
    pane_id: &str,
    terminate: &AtomicBool,
) -> Result<i32, String> {
    wait_for_status_with(status_file, terminate, || pane_exists(herdr, pane_id))
}

fn wait_for_status_with(
    status_file: &Path,
    terminate: &AtomicBool,
    mut pane_exists: impl FnMut() -> bool,
) -> Result<i32, String> {
    loop {
        if terminate.load(Ordering::SeqCst) {
            return Err("interrupted".into());
        }

        if let Some(code) = read_status_if_present(status_file)? {
            return Ok(code);
        }

        if !pane_exists() {
            // The child commits status before exiting. Re-check after observing
            // pane closure in case completion happened during the pane query.
            if let Some(code) = read_status_if_present(status_file)? {
                return Ok(code);
            }
            return Err("editor pane closed before exit status arrived".into());
        }

        thread::sleep(STATUS_POLL);
    }
}

fn read_status_if_present(status_file: &Path) -> Result<Option<i32>, String> {
    match fs::read_to_string(status_file) {
        Ok(contents) => parse_status(&contents).map(Some),
        Err(err) if err.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(err) => Err(format!("failed to read exit status: {err}")),
    }
}

fn pane_exists(herdr: &Path, pane_id: &str) -> bool {
    run_herdr_quiet(herdr, &["pane", "get", pane_id]).is_ok()
}

fn run_herdr_capture(herdr: &Path, args: &[&str]) -> Result<String, String> {
    let output = Command::new(herdr)
        .args(args)
        .output()
        .map_err(|err| format!("failed to run herdr: {err}"))?;
    if !output.status.success() {
        return Err(format!(
            "herdr {} failed",
            args.first().copied().unwrap_or("command")
        ));
    }
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

fn run_herdr_quiet(herdr: &Path, args: &[&str]) -> Result<(), String> {
    let status = Command::new(herdr)
        .args(args)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map_err(|err| format!("failed to run herdr: {err}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!(
            "herdr {} failed",
            args.first().copied().unwrap_or("command")
        ))
    }
}

fn parse_pane_id(json_text: &str) -> Result<String, String> {
    let value: Value =
        serde_json::from_str(json_text).map_err(|_| "invalid herdr JSON".to_string())?;
    value
        .pointer("/result/pane/pane_id")
        .and_then(Value::as_str)
        .filter(|s| !s.is_empty())
        .map(str::to_owned)
        .ok_or_else(|| "missing pane_id in herdr response".into())
}

fn parse_layout_height(json_text: &str, pane_id: &str) -> Result<u32, String> {
    let value: Value =
        serde_json::from_str(json_text).map_err(|_| "invalid herdr layout JSON".to_string())?;
    let panes = value
        .pointer("/result/layout/panes")
        .and_then(Value::as_array)
        .ok_or_else(|| "missing layout panes".to_string())?;

    for pane in panes {
        let id = pane.get("pane_id").and_then(Value::as_str);
        if id != Some(pane_id) {
            continue;
        }
        let height = pane
            .pointer("/rect/height")
            .and_then(Value::as_u64)
            .ok_or_else(|| "missing rect.height".to_string())?;
        if height == 0 {
            return Err("rect.height is zero".into());
        }
        return u32::try_from(height).map_err(|_| "rect.height out of range".into());
    }

    Err("pane not found in layout".into())
}

fn parse_viewport_rows(json_text: &str) -> Result<u32, String> {
    let value: Value =
        serde_json::from_str(json_text).map_err(|_| "invalid herdr pane JSON".to_string())?;
    let rows = value
        .pointer("/result/pane/scroll/viewport_rows")
        .and_then(Value::as_u64)
        .ok_or_else(|| "missing viewport_rows".to_string())?;
    if rows == 0 {
        return Err("viewport_rows is zero".into());
    }
    u32::try_from(rows).map_err(|_| "viewport_rows out of range".into())
}

fn exit_status_to_code(status: std::process::ExitStatus) -> i32 {
    if let Some(code) = status.code() {
        code
    } else if let Some(sig) = status.signal() {
        128 + sig
    } else {
        1
    }
}

fn exit_code_from_i32(code: i32) -> ExitCode {
    if (0..=255).contains(&code) {
        ExitCode::from(code as u8)
    } else {
        ExitCode::FAILURE
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_status_written_while_pane_disappears() {
        let tmp_dir = tempfile::tempdir().unwrap();
        let status_file = tmp_dir.path().join("status");
        let terminate = AtomicBool::new(false);
        let mut pane_checked = false;

        let code = wait_for_status_with(&status_file, &terminate, || {
            pane_checked = true;
            write_status(status_file.to_str().unwrap(), 0).unwrap();
            false
        })
        .unwrap();

        assert_eq!(code, 0);
        assert!(pane_checked);
    }

    #[test]
    fn errors_when_pane_disappears_without_status() {
        let tmp_dir = tempfile::tempdir().unwrap();
        let status_file = tmp_dir.path().join("status");
        let terminate = AtomicBool::new(false);

        let err = wait_for_status_with(&status_file, &terminate, || false).unwrap_err();

        assert_eq!(err, "editor pane closed before exit status arrived");
    }
}
