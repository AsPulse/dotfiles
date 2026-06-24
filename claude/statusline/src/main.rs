use chrono::{DateTime, Datelike, Duration, Local, Timelike, Utc};
use rusqlite::{Connection, OpenFlags, OptionalExtension};
use serde::Deserialize;
use std::env;
use std::fmt::Write as _;
use std::io::{Read as _, Write as _};
use std::net::{TcpListener, TcpStream};
use std::path::PathBuf;
use std::time::Duration as StdDuration;

const GREEN: &str = "\x1b[38;2;151;201;195m";
const ORANGE: &str = "\x1b[38;2;209;154;102m";
const YELLOW: &str = "\x1b[38;2;229;192;123m";
const RED: &str = "\x1b[38;2;224;108;117m";
const DIM: &str = "\x1b[2m";
const RESET: &str = "\x1b[0m";

const FIVE_HOUR_SECS: i64 = 18000;
const SEVEN_DAY_SECS: i64 = 604800;
const EXPORTER_DEFAULT_ADDR: &str = "127.0.0.1:14319";
const RATE_LIMIT_WINDOWS: [&str; 2] = ["5h", "7d"];

#[derive(Deserialize, Default)]
struct Input {
    model: Option<Model>,
    context_window: Option<ContextWindow>,
    cost: Option<Cost>,
    cwd: Option<String>,
    workspace: Option<WorkspaceInfo>,
    rate_limits: Option<RateLimits>,
}

#[derive(Deserialize, Default)]
struct Model {
    display_name: Option<String>,
}

#[derive(Deserialize, Default)]
struct ContextWindow {
    used_percentage: Option<f64>,
}

#[derive(Deserialize, Default)]
struct Cost {
    total_lines_added: Option<i64>,
    total_lines_removed: Option<i64>,
}

#[derive(Deserialize, Default)]
struct WorkspaceInfo {
    current_dir: Option<String>,
}

#[derive(Deserialize, Default)]
struct RateLimits {
    five_hour: Option<WindowUsage>,
    seven_day: Option<WindowUsage>,
}

#[derive(Deserialize, Default)]
struct WindowUsage {
    used_percentage: Option<f64>,
    resets_at: Option<i64>,
}

struct LatestRateLimit {
    window: &'static str,
    recorded_at_seconds: Option<i64>,
    used_pct: f64,
    resets_at: Option<i64>,
    records: i64,
}

fn main() {
    if env::args().skip(1).any(|arg| arg == "--exporter") {
        if let Err(err) = run_exporter() {
            eprintln!("claude-rate-limit-exporter: {err}");
            std::process::exit(1);
        }
        return;
    }

    let _ = run();
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let mut input_str = String::new();
    std::io::stdin().read_to_string(&mut input_str)?;
    let input: Input = serde_json::from_str(&input_str)?;

    let model = input.model.and_then(|m| m.display_name).unwrap_or_default();
    let ctx_str = input
        .context_window
        .and_then(|c| c.used_percentage)
        .map(|p| format!("{}", p as i64))
        .unwrap_or_else(|| "--".into());
    let lines_add = input
        .cost
        .as_ref()
        .and_then(|c| c.total_lines_added)
        .unwrap_or(0);
    let lines_rm = input
        .cost
        .as_ref()
        .and_then(|c| c.total_lines_removed)
        .unwrap_or(0);
    let cwd = input
        .workspace
        .and_then(|w| w.current_dir)
        .or(input.cwd)
        .unwrap_or_default();

    let branch = git_branch(&cwd);

    let mut line1 = format!("{model} │ {ctx_str}% │ +{lines_add}/-{lines_rm}");
    if let Some(b) = &branch {
        line1.push_str(&format!(" │ {b}"));
    }
    print!("{line1}");

    let now = Utc::now();

    record_rate_limits(&input.rate_limits, now);

    if let Some(ref rl) = input.rate_limits {
        if let Some(line) = format_window("5h", GREEN, &rl.five_hour, FIVE_HOUR_SECS, now, true) {
            print!("\n{line}");
        }
        if let Some(line) = format_window("7d", ORANGE, &rl.seven_day, SEVEN_DAY_SECS, now, false) {
            print!("\n{line}");
        }
    }

    Ok(())
}

fn record_rate_limits(rate_limits: &Option<RateLimits>, now: DateTime<Utc>) {
    let Some(rl) = rate_limits.as_ref() else {
        return;
    };

    let db_path = match std::env::var("HOME") {
        Ok(home) => format!("{home}/.local/share/claude-statusline/rate_limits.db"),
        Err(_) => return,
    };

    if let Some(parent) = std::path::Path::new(&db_path).parent() {
        let _ = std::fs::create_dir_all(parent);
    }

    let Ok(conn) = Connection::open(&db_path) else {
        return;
    };

    let _ = conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS rate_limits (
            recorded_at  TEXT NOT NULL,
            window       TEXT NOT NULL,
            used_pct     REAL NOT NULL,
            resets_at    INTEGER
        )",
    );

    // ロック取得失敗時は記録をスキップ（表示には影響させない）
    if conn.execute_batch("BEGIN IMMEDIATE").is_err() {
        return;
    }

    let ts = now.to_rfc3339();

    let insert = |window: &str, w: &WindowUsage| {
        let Some(pct) = w.used_percentage else { return };

        let prev_resets_at: Option<i64> = conn
            .query_row(
                "SELECT resets_at FROM rate_limits WHERE window = ?1 ORDER BY recorded_at DESC LIMIT 1",
                (window,),
                |row| row.get(0),
            )
            .ok();

        let current_resets_at = w.resets_at.unwrap_or(0);
        if prev_resets_at != Some(current_resets_at) {
            if let Some(prev_ra) = prev_resets_at {
                // 前ウィンドウの天井を resets_at の1秒前に記録
                let peak_pct: f64 = conn
                    .query_row(
                        "SELECT MAX(used_pct) FROM rate_limits WHERE window = ?1 AND resets_at = ?2",
                        (window, prev_ra),
                        |row| row.get(0),
                    )
                    .unwrap_or(0.0);
                let before_reset = timestamp_to_utc(prev_ra) - Duration::seconds(1);
                let _ = conn.execute(
                    "INSERT INTO rate_limits (recorded_at, window, used_pct, resets_at) VALUES (?1, ?2, ?3, ?4)",
                    (before_reset.to_rfc3339(), window, peak_pct, prev_ra),
                );

                // resets_at ちょうどに 0% を記録
                let at_reset = timestamp_to_utc(prev_ra);
                let _ = conn.execute(
                    "INSERT INTO rate_limits (recorded_at, window, used_pct, resets_at) VALUES (?1, ?2, ?3, ?4)",
                    (at_reset.to_rfc3339(), window, 0.0, current_resets_at),
                );
            }

            let _ = conn.execute(
                "INSERT INTO rate_limits (recorded_at, window, used_pct, resets_at) VALUES (?1, ?2, ?3, ?4)",
                (&ts, window, pct, w.resets_at),
            );
            return;
        }

        // 同一ウィンドウ内: 記録値 = max(現在値, 最新DB値)
        let prev_pct: f64 = conn
            .query_row(
                "SELECT used_pct FROM rate_limits WHERE window = ?1 ORDER BY recorded_at DESC LIMIT 1",
                (window,),
                |row| row.get(0),
            )
            .unwrap_or(0.0);
        let record_pct = pct.max(prev_pct);

        // 同じ値が何行あるか（同一 resets_at 内）
        let dup_count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM rate_limits WHERE window = ?1 AND resets_at = ?2 AND used_pct = ?3",
                (window, w.resets_at, record_pct),
                |row| row.get(0),
            )
            .unwrap_or(0);

        if dup_count < 2 {
            let _ = conn.execute(
                "INSERT INTO rate_limits (recorded_at, window, used_pct, resets_at) VALUES (?1, ?2, ?3, ?4)",
                (&ts, window, record_pct, w.resets_at),
            );
        } else {
            // 2個目の recorded_at を現在時刻に更新
            let _ = conn.execute(
                "UPDATE rate_limits SET recorded_at = ?1
                 WHERE rowid = (
                     SELECT rowid FROM rate_limits
                     WHERE window = ?2 AND resets_at = ?3 AND used_pct = ?4
                     ORDER BY recorded_at DESC LIMIT 1
                 )",
                (&ts, window, w.resets_at, record_pct),
            );
        }
    };

    if !is_stale(&rl.five_hour, now) {
        if let Some(w) = &rl.five_hour {
            insert("5h", w);
        }
    }
    if !is_stale(&rl.seven_day, now) {
        if let Some(w) = &rl.seven_day {
            insert("7d", w);
        }
    }

    let _ = conn.execute_batch("COMMIT");
}

fn git_branch(cwd: &str) -> Option<String> {
    if cwd.is_empty() {
        return None;
    }
    std::process::Command::new("git")
        .args(["-C", cwd, "symbolic-ref", "--short", "HEAD"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .or_else(|| {
            std::process::Command::new("git")
                .args(["-C", cwd, "rev-parse", "--short", "HEAD"])
                .output()
                .ok()
                .filter(|o| o.status.success())
                .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        })
        .filter(|s| !s.is_empty())
}

fn timestamp_to_utc(ts: i64) -> DateTime<Utc> {
    DateTime::from_timestamp(ts, 0).unwrap_or_default()
}

fn color_for_pct(pct: i64) -> &'static str {
    if pct >= 80 {
        RED
    } else if pct >= 50 {
        YELLOW
    } else {
        GREEN
    }
}

fn progress_bar(pct: i64, color_override: Option<&str>) -> String {
    let filled = ((pct + 2) / 5).clamp(0, 20) as usize;
    let empty = 20 - filled;
    let color = color_override.unwrap_or_else(|| color_for_pct(pct));
    format!(
        "{color}{}{DIM}{}{RESET}",
        "━".repeat(filled),
        "╌".repeat(empty),
    )
}

fn predict_utilization(
    utilization: f64,
    reset_time: DateTime<Utc>,
    window_secs: i64,
    now: DateTime<Utc>,
) -> Option<i64> {
    if utilization <= 0.0 {
        return None;
    }
    let remaining = reset_time.signed_duration_since(now).num_seconds();
    if remaining <= 0 {
        return None;
    }
    let elapsed = window_secs - remaining;
    if elapsed <= window_secs / 20 {
        return None;
    }
    Some((utilization * window_secs as f64 / elapsed as f64) as i64)
}

fn format_reset_relative(reset_time: DateTime<Utc>, now: DateTime<Utc>) -> Option<String> {
    let remaining = reset_time.signed_duration_since(now).num_seconds();
    if remaining <= 0 {
        return None;
    }
    let d = remaining / 86400;
    let h = (remaining % 86400) / 3600;
    let m = (remaining % 3600) / 60;
    let mut rel = String::new();
    if d > 0 {
        rel.push_str(&format!("{d}d "));
    }
    if d > 0 || h > 0 {
        rel.push_str(&format!("{h}hr "));
    }
    rel.push_str(&format!("{m}min"));
    Some(format!("in {rel}"))
}

fn format_reset_absolute(reset_time: DateTime<Utc>) -> Option<String> {
    let local = reset_time.with_timezone(&Local);

    let rounded = if local.minute() >= 30 {
        local + Duration::hours(1)
    } else {
        local
    };

    let hour12 = match rounded.hour() % 12 {
        0 => 12,
        h => h,
    };
    let ampm = if rounded.hour() >= 12 { "pm" } else { "am" };

    let now_local = Local::now();
    if rounded.date_naive() == now_local.date_naive() {
        Some(format!("at {hour12}{ampm}"))
    } else {
        const MONTHS: [&str; 12] = [
            "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
        ];
        let mon = MONTHS[rounded.month0() as usize];
        let day = rounded.day();
        Some(format!("at {mon} {day} {hour12}{ampm}"))
    }
}

fn is_stale(window: &Option<WindowUsage>, now: DateTime<Utc>) -> bool {
    window
        .as_ref()
        .and_then(|w| w.resets_at)
        .is_some_and(|ra| timestamp_to_utc(ra) <= now)
}

fn format_window(
    label: &str,
    label_color: &str,
    window: &Option<WindowUsage>,
    window_secs: i64,
    now: DateTime<Utc>,
    relative_reset: bool,
) -> Option<String> {
    let w = window.as_ref()?;
    let _ = w.used_percentage?;

    if is_stale(window, now) {
        return Some(format!("{label_color}{label}{RESET}  {DIM}staled{RESET}"));
    }

    let util = w.used_percentage.unwrap();
    let util_int = util as i64;

    let bar_color = if !relative_reset { Some(ORANGE) } else { None };
    let bar = progress_bar(util_int, bar_color);

    let mut line = format!("{label_color}{label}{RESET}  {bar} {DIM}{util_int:>3}%{RESET}");

    if let Some(resets_at) = w.resets_at {
        let reset_time = timestamp_to_utc(resets_at);

        if let Some(pred) = predict_utilization(util, reset_time, window_secs, now) {
            let pred_color = if relative_reset {
                color_for_pct(pred)
            } else {
                ORANGE
            };
            let pred_str = if pred >= 1000 {
                "999+".to_string()
            } else {
                format!("{pred:>3}")
            };
            line.push_str(&format!(" {DIM}>{RESET}{pred_color}{pred_str}%{RESET}"));
        } else {
            line.push_str("      ");
        }

        let reset_str = if relative_reset {
            format_reset_relative(reset_time, now)
        } else {
            format_reset_absolute(reset_time)
        };
        if let Some(rs) = reset_str {
            line.push_str(&format!("   {DIM}Resets {rs}{RESET}"));
        }
    }

    Some(line)
}

fn run_exporter() -> Result<(), Box<dyn std::error::Error>> {
    let addr = env::var("CLAUDE_STATUSLINE_EXPORTER_ADDR")
        .unwrap_or_else(|_| EXPORTER_DEFAULT_ADDR.into());
    let listener = TcpListener::bind(&addr)?;
    eprintln!("claude-rate-limit-exporter listening on http://{addr}/metrics");

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                if let Err(err) = handle_exporter_client(stream) {
                    eprintln!("claude-rate-limit-exporter: request failed: {err}");
                }
            }
            Err(err) => eprintln!("claude-rate-limit-exporter: accept failed: {err}"),
        }
    }

    Ok(())
}

fn handle_exporter_client(mut stream: TcpStream) -> std::io::Result<()> {
    let _ = stream.set_read_timeout(Some(StdDuration::from_secs(2)));

    let mut buffer = [0_u8; 1024];
    let bytes_read = stream.read(&mut buffer)?;
    let request = String::from_utf8_lossy(&buffer[..bytes_read]);
    let path = request
        .lines()
        .next()
        .and_then(|line| line.split_whitespace().nth(1))
        .unwrap_or("/");

    let (status, content_type, body) = match path {
        "/" => (
            "200 OK",
            "text/plain; charset=utf-8",
            "claude-rate-limit-exporter\n\nGET /metrics\n".to_string(),
        ),
        "/metrics" => (
            "200 OK",
            "text/plain; version=0.0.4",
            render_exporter_metrics(),
        ),
        _ => (
            "404 Not Found",
            "text/plain; charset=utf-8",
            "not found\n".to_string(),
        ),
    };

    let response = format!(
        "HTTP/1.1 {status}\r\nContent-Type: {content_type}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    );
    stream.write_all(response.as_bytes())
}

fn render_exporter_metrics() -> String {
    let mut out = String::new();
    let now = Utc::now().timestamp();

    out.push_str("# HELP claude_code_rate_limit_exporter_up Whether the Claude Code rate limit exporter could read the SQLite database.\n");
    out.push_str("# TYPE claude_code_rate_limit_exporter_up gauge\n");
    out.push_str("# HELP claude_code_rate_limit_used_percent Latest Claude Code usage limit percentage from statusline.\n");
    out.push_str("# TYPE claude_code_rate_limit_used_percent gauge\n");
    out.push_str("# HELP claude_code_rate_limit_recorded_at_seconds Unix timestamp for the latest statusline record.\n");
    out.push_str("# TYPE claude_code_rate_limit_recorded_at_seconds gauge\n");
    out.push_str("# HELP claude_code_rate_limit_resets_at_seconds Unix timestamp when the current Claude Code rate limit window resets.\n");
    out.push_str("# TYPE claude_code_rate_limit_resets_at_seconds gauge\n");
    out.push_str("# HELP claude_code_rate_limit_seconds_until_reset Seconds until the current Claude Code rate limit window resets.\n");
    out.push_str("# TYPE claude_code_rate_limit_seconds_until_reset gauge\n");
    out.push_str("# HELP claude_code_rate_limit_staleness_seconds Seconds since the latest statusline record.\n");
    out.push_str("# TYPE claude_code_rate_limit_staleness_seconds gauge\n");
    out.push_str("# HELP claude_code_rate_limit_records Number of records stored in the local statusline SQLite database.\n");
    out.push_str("# TYPE claude_code_rate_limit_records gauge\n");

    match read_latest_rate_limits() {
        Ok(limits) => {
            out.push_str("claude_code_rate_limit_exporter_up 1\n");
            for limit in limits {
                let window = limit.window;
                let _ = writeln!(
                    out,
                    "claude_code_rate_limit_used_percent{{window=\"{window}\"}} {}",
                    limit.used_pct
                );
                let _ = writeln!(
                    out,
                    "claude_code_rate_limit_records{{window=\"{window}\"}} {}",
                    limit.records
                );

                if let Some(recorded_at) = limit.recorded_at_seconds {
                    let _ = writeln!(
                        out,
                        "claude_code_rate_limit_recorded_at_seconds{{window=\"{window}\"}} {recorded_at}"
                    );
                    let _ = writeln!(
                        out,
                        "claude_code_rate_limit_staleness_seconds{{window=\"{window}\"}} {}",
                        now.saturating_sub(recorded_at)
                    );
                }

                if let Some(resets_at) = limit.resets_at {
                    let _ = writeln!(
                        out,
                        "claude_code_rate_limit_resets_at_seconds{{window=\"{window}\"}} {resets_at}"
                    );
                    let _ = writeln!(
                        out,
                        "claude_code_rate_limit_seconds_until_reset{{window=\"{window}\"}} {}",
                        resets_at.saturating_sub(now)
                    );
                }
            }
        }
        Err(err) => {
            let _ = writeln!(
                out,
                "# scrape_error: {}",
                err.to_string().replace('\n', " ")
            );
            out.push_str("claude_code_rate_limit_exporter_up 0\n");
        }
    }

    out
}

fn read_latest_rate_limits() -> Result<Vec<LatestRateLimit>, Box<dyn std::error::Error>> {
    let db_path = exporter_db_path()?;
    let conn = Connection::open_with_flags(db_path, OpenFlags::SQLITE_OPEN_READ_ONLY)?;
    conn.busy_timeout(StdDuration::from_millis(200))?;
    let mut limits = Vec::new();

    for window in RATE_LIMIT_WINDOWS {
        let latest = conn
            .query_row(
                "SELECT recorded_at, used_pct, resets_at
                 FROM rate_limits
                 WHERE window = ?1
                 ORDER BY recorded_at DESC
                 LIMIT 1",
                (window,),
                |row| {
                    let recorded_at: String = row.get(0)?;
                    let used_pct: f64 = row.get(1)?;
                    let resets_at: Option<i64> = row.get(2)?;
                    Ok((recorded_at, used_pct, resets_at))
                },
            )
            .optional()?;

        let Some((recorded_at, used_pct, resets_at)) = latest else {
            continue;
        };

        let records = conn.query_row(
            "SELECT COUNT(*) FROM rate_limits WHERE window = ?1",
            (window,),
            |row| row.get(0),
        )?;

        limits.push(LatestRateLimit {
            window,
            recorded_at_seconds: parse_recorded_at(&recorded_at),
            used_pct,
            resets_at,
            records,
        });
    }

    Ok(limits)
}

fn exporter_db_path() -> Result<PathBuf, Box<dyn std::error::Error>> {
    if let Ok(path) = env::var("CLAUDE_STATUSLINE_DB") {
        return Ok(path.into());
    }

    let home = env::var("HOME")?;
    Ok(PathBuf::from(home).join(".local/share/claude-statusline/rate_limits.db"))
}

fn parse_recorded_at(value: &str) -> Option<i64> {
    DateTime::parse_from_rfc3339(value)
        .map(|dt| dt.timestamp())
        .ok()
}
