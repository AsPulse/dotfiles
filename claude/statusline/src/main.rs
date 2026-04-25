use chrono::{DateTime, Datelike, Duration, Local, Timelike, Utc};
use rusqlite::Connection;
use serde::Deserialize;
use std::io::Read as _;

const GREEN: &str = "\x1b[38;2;151;201;195m";
const ORANGE: &str = "\x1b[38;2;209;154;102m";
const YELLOW: &str = "\x1b[38;2;229;192;123m";
const RED: &str = "\x1b[38;2;224;108;117m";
const DIM: &str = "\x1b[2m";
const RESET: &str = "\x1b[0m";

const FIVE_HOUR_SECS: i64 = 18000;
const SEVEN_DAY_SECS: i64 = 604800;

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

fn main() {
    let _ = run();
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let mut input_str = String::new();
    std::io::stdin().read_to_string(&mut input_str)?;
    let input: Input = serde_json::from_str(&input_str)?;

    let model = input
        .model
        .and_then(|m| m.display_name)
        .unwrap_or_default();
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
        if let Some(line) =
            format_window("5h", GREEN, &rl.five_hour, FIVE_HOUR_SECS, now, true)
        {
            print!("\n{line}");
        }
        if let Some(line) =
            format_window("7d", ORANGE, &rl.seven_day, SEVEN_DAY_SECS, now, false)
        {
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

    let bar_color = if !relative_reset {
        Some(ORANGE)
    } else {
        None
    };
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
