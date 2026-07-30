//! Drive one or more running Blender instances over the Blender Lab MCP add-on's
//! TCP socket, without going through an MCP client.
//!
//! The add-on speaks a trivial protocol — a single JSON object terminated by a NUL
//! byte, answered the same way — so the port can be chosen per invocation. That is
//! what makes per-subagent instances possible: an MCP server binds its target port
//! at startup and is shared by every subagent, whereas here the port is just an
//! argument.

use clap::{Parser, Subcommand};
use std::error::Error;
use std::ffi::OsString;
use std::fs;
use std::io::{Read, Write};
use std::net::{Ipv4Addr, SocketAddr, TcpListener, TcpStream};
use std::os::unix::fs::{FileTypeExt, MetadataExt};
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant, SystemTime};

type Res<T> = Result<T, Box<dyn Error>>;

const HOST: Ipv4Addr = Ipv4Addr::LOCALHOST;
/// The add-on's own default. Keeping the first instance here means a plain
/// Blender launched outside this tool still lands on a port we know about.
const PORT_BASE: u16 = 9876;
const PORT_LAST: u16 = 9899;
/// Workspace 1 is Steam's, so instances start at 2.
const WORKSPACE_BASE: u32 = 2;

const CONNECT_TIMEOUT: Duration = Duration::from_secs(5);
const PROBE_TIMEOUT: Duration = Duration::from_millis(300);
/// Renders and heavy scene edits block the add-on until they finish.
const EXEC_TIMEOUT: Duration = Duration::from_secs(600);
const SPAWN_TIMEOUT: Duration = Duration::from_secs(120);

#[derive(Parser)]
#[command(name = "blender-cli", version, about = "Drive Blender instances over the MCP add-on socket")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Start a new instance and print the port it was given
    Spawn {
        /// sway workspace to place it on (default: derived from the port)
        #[arg(long)]
        workspace: Option<u32>,
    },
    /// Start an instance on a specific port unless one is already running there
    Ensure {
        #[arg(long)]
        port: u16,
        #[arg(long)]
        workspace: Option<u32>,
    },
    /// Run Python inside an instance
    Exec {
        #[arg(long)]
        port: u16,
        /// Python source; use `-` to read it from stdin
        code: Option<String>,
        /// Read Python source from a file
        #[arg(long, conflicts_with = "code")]
        file: Option<PathBuf>,
        /// Print the add-on's raw JSON reply
        #[arg(long)]
        json: bool,
    },
    /// List running instances
    Ls {
        #[arg(long)]
        json: bool,
    },
    /// Ask an instance to quit
    Kill {
        #[arg(long, conflicts_with = "all")]
        port: Option<u16>,
        #[arg(long)]
        all: bool,
    },
    /// Print the root of the bundled Blender API reference and manual (RST)
    DocsPath,
}

fn main() {
    if let Err(e) = run() {
        eprintln!("blender-cli: {e}");
        std::process::exit(1);
    }
}

fn run() -> Res<()> {
    match Cli::parse().cmd {
        Cmd::Spawn { workspace } => {
            let port = free_port()?;
            start(port, workspace)?;
            println!("{port}");
            Ok(())
        }
        Cmd::Ensure { port, workspace } => {
            if !alive(port) {
                start(port, workspace)?;
            }
            println!("{port}");
            Ok(())
        }
        Cmd::Exec {
            port,
            code,
            file,
            json,
        } => exec(port, read_source(code, file)?, json),
        Cmd::Ls { json } => list(json),
        Cmd::Kill { port, all } => kill(port, all),
        Cmd::DocsPath => {
            println!("{}", env_path("BLENDER_CLI_DOCS")?.display());
            Ok(())
        }
    }
}

// --- add-on protocol ---------------------------------------------------------

/// Send Python to the add-on and return its decoded reply.
fn send(port: u16, code: &str, timeout: Duration) -> Res<serde_json::Value> {
    let addr = SocketAddr::from((HOST, port));
    let mut sock = TcpStream::connect_timeout(&addr, CONNECT_TIMEOUT).map_err(|e| {
        format!("cannot reach a Blender instance on port {port} ({e}); is it running?")
    })?;
    sock.set_read_timeout(Some(timeout))?;
    sock.set_write_timeout(Some(timeout))?;

    let mut req = serde_json::to_vec(&serde_json::json!({
        "type": "execute",
        "code": code,
        "strict_json": false,
    }))?;
    req.push(0);
    sock.write_all(&req)?;

    let mut buf = Vec::new();
    let mut chunk = [0u8; 65536];
    loop {
        let n = sock.read(&mut chunk)?;
        if n == 0 {
            break;
        }
        buf.extend_from_slice(&chunk[..n]);
        if buf.contains(&0) {
            break;
        }
    }
    let end = buf.iter().position(|b| *b == 0).unwrap_or(buf.len());
    Ok(serde_json::from_slice(&buf[..end])?)
}

fn alive(port: u16) -> bool {
    TcpStream::connect_timeout(&SocketAddr::from((HOST, port)), PROBE_TIMEOUT).is_ok()
}

// --- subcommands -------------------------------------------------------------

fn exec(port: u16, code: String, json: bool) -> Res<()> {
    let reply = send(port, &code, EXEC_TIMEOUT)?;

    if json {
        println!("{}", serde_json::to_string_pretty(&reply)?);
        return Ok(());
    }

    if let Some(s) = reply.get("stdout").and_then(|v| v.as_str()) {
        print!("{s}");
    }
    if let Some(s) = reply.get("stderr").and_then(|v| v.as_str()) {
        eprint!("{s}");
    }
    // `strict_json: false` leaves `result` empty for plain statements, so only
    // surface it when the code actually evaluated to something.
    match reply.get("result") {
        Some(v) if !v.is_null() && v.as_object().is_none_or(|o| !o.is_empty()) => {
            println!("{}", serde_json::to_string_pretty(v)?);
        }
        _ => {}
    }

    if reply.get("status").and_then(|v| v.as_str()) != Some("ok") {
        let msg = reply
            .get("message")
            .and_then(|v| v.as_str())
            .unwrap_or("execution failed");
        return Err(msg.into());
    }
    Ok(())
}

fn list(json: bool) -> Res<()> {
    let mut ports: Vec<u16> = Vec::new();
    if let Ok(entries) = fs::read_dir(state_root()) {
        for e in entries.flatten() {
            if let Some(p) = e.file_name().to_str().and_then(|s| s.parse::<u16>().ok())
                && alive(p)
            {
                ports.push(p);
            }
        }
    }
    ports.sort_unstable();

    if json {
        let rows: Vec<_> = ports
            .iter()
            .map(|p| serde_json::json!({ "port": p, "workspace": workspace_for(*p) }))
            .collect();
        println!("{}", serde_json::to_string_pretty(&rows)?);
    } else if ports.is_empty() {
        eprintln!("no running instances");
    } else {
        println!("{:<6} WORKSPACE", "PORT");
        for p in ports {
            println!("{:<6} {}", p, workspace_for(p));
        }
    }
    Ok(())
}

fn kill(port: Option<u16>, all: bool) -> Res<()> {
    let targets: Vec<u16> = match (port, all) {
        (Some(p), _) => vec![p],
        (None, true) => (PORT_BASE..=PORT_LAST).filter(|p| alive(*p)).collect(),
        (None, false) => return Err("pass --port or --all".into()),
    };
    for p in targets {
        // `wm.quit_blender` is blocked by the add-on's sandbox; `bpy.app.quit()` is
        // the sanctioned path. The socket dies with the process, so a missing or
        // truncated reply is the expected outcome rather than a failure.
        let _ = send(p, "import bpy\nbpy.app.quit()", Duration::from_secs(10));
        println!("{p}");
    }
    Ok(())
}

// --- launching ---------------------------------------------------------------

fn start(port: u16, workspace: Option<u32>) -> Res<()> {
    prepare_config(port)?;
    // New windows open on whichever workspace has focus, so switching first is
    // what actually places the instance. Failing here only costs us the placement.
    switch_workspace(workspace.unwrap_or_else(|| workspace_for(port)));

    let blender = env_path("BLENDER_CLI_BLENDER")?;
    let mut cmd = Command::new(&blender);
    // The add-on refuses to start its server unless `bpy.app.online_access` is set,
    // and it treats even a localhost socket as "online". Passing the flag here lets
    // BLENDER_CLI_BLENDER stay the plain nixpkgs blender instead of a pre-wrapped one.
    cmd.arg("--online-mode")
        .env("BLENDER_USER_CONFIG", config_dir(port))
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .process_group(0);

    // Agents drive this over SSH, where WAYLAND_DISPLAY is not set. Without it Blender
    // finds no compositor, exits immediately, and the only symptom is that the port
    // never opens — so resolve the running session's socket ourselves.
    let runtime = runtime_dir();
    if let Some(display) = wayland_display(&runtime) {
        cmd.env("XDG_RUNTIME_DIR", &runtime)
            .env("WAYLAND_DISPLAY", display)
            .env("XDG_SESSION_TYPE", "wayland");
    }

    cmd.spawn()
        .map_err(|e| format!("failed to launch {}: {e}", blender.display()))?;

    let deadline = Instant::now() + SPAWN_TIMEOUT;
    while Instant::now() < deadline {
        if alive(port) {
            return Ok(());
        }
        std::thread::sleep(Duration::from_millis(250));
    }
    Err(format!("Blender started but never listened on port {port}").into())
}

/// Give the instance its own `BLENDER_USER_CONFIG`, since the add-on reads its
/// port from user preferences and those are global to a config directory.
/// Extensions stay shared — only the enabled flag and the port are per-config.
fn prepare_config(port: u16) -> Res<()> {
    let blender = env_path("BLENDER_CLI_BLENDER")?;
    let addon = env_path("BLENDER_CLI_ADDON_ZIP")?;
    let cfg = config_dir(port);
    let marker = state_root().join(port.to_string()).join("addon");

    if fs::read(&marker).ok().as_deref() == Some(addon.as_os_str().as_encoded_bytes()) {
        return Ok(());
    }
    fs::create_dir_all(&cfg)?;

    run_command(Command::new(&blender)
        .env("BLENDER_USER_CONFIG", &cfg)
        .args([
            "--online-mode",
            "--command",
            "extension",
            "install-file",
            "-r",
            "user_default",
            "--enable",
        ])
        .arg(&addon))?;

    run_command(Command::new(&blender)
        .env("BLENDER_USER_CONFIG", &cfg)
        .args(["--online-mode", "--background", "--python-expr"])
        .arg(format!(
            "import bpy\n\
             prefs = bpy.context.preferences.addons['bl_ext.user_default.mcp'].preferences\n\
             prefs.port = {port}\n\
             prefs.use_autostart = True\n\
             bpy.ops.wm.save_userpref()\n"
        )))?;

    fs::write(&marker, addon.as_os_str().as_encoded_bytes())?;
    Ok(())
}

fn run_command(cmd: &mut Command) -> Res<()> {
    let out = cmd.stdin(Stdio::null()).output()?;
    if !out.status.success() {
        return Err(format!(
            "{:?} failed: {}",
            cmd.get_program(),
            String::from_utf8_lossy(&out.stderr).trim()
        )
        .into());
    }
    Ok(())
}

fn switch_workspace(ws: u32) {
    let Some(swaymsg) = std::env::var_os("BLENDER_CLI_SWAYMSG") else {
        return;
    };
    let mut cmd = Command::new(swaymsg);
    cmd.args(["workspace", "number", &ws.to_string()])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    if let Some(sock) = sway_socket(&runtime_dir()) {
        cmd.env("SWAYSOCK", sock);
    }
    let _ = cmd.status();
}

// --- paths -------------------------------------------------------------------

fn free_port() -> Res<u16> {
    (PORT_BASE..=PORT_LAST)
        .find(|p| TcpListener::bind((HOST, *p)).is_ok())
        .ok_or_else(|| format!("no free port in {PORT_BASE}..={PORT_LAST}").into())
}

fn workspace_for(port: u16) -> u32 {
    WORKSPACE_BASE + u32::from(port.saturating_sub(PORT_BASE))
}

fn runtime_dir() -> PathBuf {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(format!("/run/user/{}", current_uid())))
}

fn current_uid() -> u32 {
    fs::metadata("/proc/self").map(|m| m.uid()).unwrap_or(1000)
}

/// Newest socket under `dir` whose name starts with `prefix`. Sockets from dead
/// sessions are routinely left behind, so recency is the only usable tiebreaker.
fn newest_socket(dir: &Path, prefix: &str) -> Option<OsString> {
    let mut newest: Option<(OsString, SystemTime)> = None;
    for entry in fs::read_dir(dir).ok()?.flatten() {
        let name = entry.file_name();
        let Some(text) = name.to_str() else { continue };
        if !text.starts_with(prefix) {
            continue;
        }
        let Ok(meta) = entry.metadata() else { continue };
        // Skips the `.lock` files sitting next to the Wayland sockets.
        if !meta.file_type().is_socket() {
            continue;
        }
        let stamp = meta.modified().unwrap_or(SystemTime::UNIX_EPOCH);
        if newest.as_ref().is_none_or(|(_, best)| stamp > *best) {
            newest = Some((name, stamp));
        }
    }
    newest.map(|(name, _)| name)
}

fn wayland_display(dir: &Path) -> Option<OsString> {
    std::env::var_os("WAYLAND_DISPLAY").or_else(|| newest_socket(dir, "wayland-"))
}

/// swaymsg exits 1 with "Unable to retrieve socket path" when SWAYSOCK is unset,
/// which is the normal state outside the compositor's own children.
fn sway_socket(dir: &Path) -> Option<OsString> {
    std::env::var_os("SWAYSOCK")
        .or_else(|| newest_socket(dir, "sway-ipc.").map(|n| dir.join(n).into_os_string()))
}

fn state_root() -> PathBuf {
    let base = std::env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/state")
        });
    base.join("blender-cli")
}

fn config_dir(port: u16) -> PathBuf {
    state_root().join(port.to_string()).join("config")
}

fn env_path(key: &str) -> Res<PathBuf> {
    std::env::var_os(key)
        .map(PathBuf::from)
        .ok_or_else(|| format!("{key} is not set; blender-cli expects its Nix wrapper").into())
}

fn read_source(code: Option<String>, file: Option<PathBuf>) -> Res<String> {
    match (code.as_deref(), file) {
        (_, Some(f)) => Ok(fs::read_to_string(f)?),
        (Some("-"), None) | (None, None) => {
            let mut s = String::new();
            std::io::stdin().read_to_string(&mut s)?;
            Ok(s)
        }
        (Some(c), None) => Ok(c.to_owned()),
    }
}
