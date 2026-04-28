#!/usr/bin/env python3
"""Plot rate limit usage from SQLite as an interactive Plotly chart."""

import argparse
import os
from pathlib import Path
import shlex
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from datetime import datetime, timezone, timedelta

DB_PATH = os.path.expanduser("~/.local/share/claude-statusline/rate_limits.db")
DEFAULT_OUT = Path(tempfile.gettempdir()) / "rate_limit.html"
JST = timezone(timedelta(hours=9))


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=DEFAULT_OUT,
        help=f"output HTML path (default: {DEFAULT_OUT})",
    )
    parser.add_argument(
        "--no-open",
        action="store_true",
        help="write the HTML file without opening it",
    )
    return parser.parse_args()


def browser_env_commands(browser, path):
    for candidate in browser.split(os.pathsep):
        candidate = candidate.strip()
        if not candidate:
            continue
        if "%s" in candidate:
            yield shlex.split(candidate.replace("%s", shlex.quote(str(path))))
        else:
            yield shlex.split(candidate) + [str(path)]


def open_html(path):
    commands = []
    browser = os.environ.get("BROWSER")
    if browser:
        commands.extend(browser_env_commands(browser, path))
    if sys.platform == "darwin":
        commands.append(["open", str(path)])
    if shutil.which("xdg-open"):
        commands.append(["xdg-open", str(path)])

    failures = []
    for command in commands:
        try:
            subprocess.run(command, check=True)
            return command[0]
        except (FileNotFoundError, subprocess.CalledProcessError) as exc:
            failures.append(f"{command[0]}: {exc}")

    detail = "\n".join(failures)
    if detail:
        raise RuntimeError(f"failed to open {path}\n{detail}")
    raise RuntimeError("no browser opener found; set BROWSER or use --no-open")


def parse(rows):
    times = [datetime.fromisoformat(r[0]).astimezone(JST) for r in rows]
    pcts = [r[1] for r in rows]
    return times, pcts


def smooth_time_based(times, pcts, interval_sec=60, window_sec=600):
    import numpy as np
    from scipy.ndimage import uniform_filter1d

    ts = np.array([t.timestamp() for t in times])
    t_uniform = np.arange(ts[0], ts[-1], interval_sec)
    p_uniform = np.interp(t_uniform, ts, pcts)
    kernel_size = max(1, int(window_sec / interval_sec))
    p_smooth = uniform_filter1d(p_uniform, size=kernel_size, mode="nearest")
    t_dt = [datetime.fromtimestamp(t, tz=JST) for t in t_uniform]
    return t_dt, p_smooth


def main():
    args = parse_args()

    import plotly.graph_objects as go

    conn = sqlite3.connect(DB_PATH)
    rows_5h = conn.execute(
        "SELECT recorded_at, used_pct FROM rate_limits WHERE window = '5h' ORDER BY recorded_at"
    ).fetchall()
    rows_7d = conn.execute(
        "SELECT recorded_at, used_pct FROM rate_limits WHERE window = '7d' ORDER BY recorded_at"
    ).fetchall()
    conn.close()

    fig = go.Figure()

    t5, p5 = parse(rows_5h)
    t7, p7 = parse(rows_7d)
    t5s, p5s = smooth_time_based(t5, p5, window_sec=900)
    t7s, p7s = smooth_time_based(t7, p7, window_sec=3600)

    fig.add_trace(go.Scatter(x=t5, y=p5, mode="lines", name="5h (raw)", line=dict(color="rgba(59,130,246,0.5)", width=1)))
    fig.add_trace(go.Scatter(x=t5s, y=p5s.tolist(), mode="lines", name="5h", line=dict(color="#3b82f6", width=2.5)))
    fig.add_trace(go.Scatter(x=t7, y=p7, mode="lines", name="7d (raw)", line=dict(color="rgba(249,115,22,0.5)", width=1)))
    fig.add_trace(go.Scatter(x=t7s, y=p7s.tolist(), mode="lines", name="7d", line=dict(color="#f97316", width=2.5)))

    fig.update_layout(
        title="Rate Limit Usage",
        yaxis_title="used_pct (%)",
        template="plotly_dark",
        hovermode="x unified",
        legend=dict(orientation="h", yanchor="bottom", y=1.02),
    )

    out = args.output.expanduser().resolve()
    fig.write_html(out)
    if args.no_open:
        print(f"Wrote {out}")
        return

    opener = open_html(out)
    print(f"Opened {out} via {opener}")


if __name__ == "__main__":
    main()
