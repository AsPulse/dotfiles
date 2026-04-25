#!/usr/bin/env python3
"""Plot rate limit usage from SQLite as an interactive Plotly chart."""

import os
import sqlite3
import subprocess
import sys
import tempfile

import numpy as np
import plotly.graph_objects as go
from scipy.ndimage import uniform_filter1d
from datetime import datetime, timezone, timedelta

DB_PATH = os.path.expanduser("~/.local/share/claude-statusline/rate_limits.db")
JST = timezone(timedelta(hours=9))


def parse(rows):
    times = [datetime.fromisoformat(r[0]).astimezone(JST) for r in rows]
    pcts = [r[1] for r in rows]
    return times, pcts


def smooth_time_based(times, pcts, interval_sec=60, window_sec=600):
    ts = np.array([t.timestamp() for t in times])
    t_uniform = np.arange(ts[0], ts[-1], interval_sec)
    p_uniform = np.interp(t_uniform, ts, pcts)
    kernel_size = max(1, int(window_sec / interval_sec))
    p_smooth = uniform_filter1d(p_uniform, size=kernel_size, mode="nearest")
    t_dt = [datetime.fromtimestamp(t, tz=JST) for t in t_uniform]
    return t_dt, p_smooth


def main():
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

    out = os.path.join(tempfile.gettempdir(), "rate_limit.html")
    fig.write_html(out)
    subprocess.run(["open", out])
    print(f"Opened {out}")


if __name__ == "__main__":
    main()
