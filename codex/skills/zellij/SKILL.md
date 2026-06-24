---
name: zellij
description: Inspect and operate Zellij sessions from Codex. Use when the user asks Codex to read output from a Zellij pane, send commands or keys to a pane, target panes by title/tab/command/cwd, or otherwise interact with a live Zellij terminal multiplexer session.
---

# Zellij

## Rule

- Always inspect the Zellij session first.
- Resolve the target pane to an explicit `pane_id`, for example `terminal_3`.
- Only then send input or read output.
- Never assume the currently focused pane is the intended target.
- When the user asks to perform work through Zellij, a specific tab, or a
  specific pane, do that work by sending input to that Zellij pane. Do not run
  the same or equivalent work outside Zellij via `exec_command`, direct shell
  commands, Kubernetes access, or another tool path unless the user explicitly
  changes the execution path.
- If Zellij access is blocked, stop and report the blocker instead of bypassing
  the requested pane. Do not present work done outside Zellij as if it happened
  in the requested pane.
- Prefer interactive, step-by-step operation. Send one command or key sequence, read the pane output, then decide the next action, like a human using a terminal.
- Do not paste a large batch of commands unless the user explicitly asks for batch execution or the command sequence is already known to be safe and non-interactive.
- Zellij commands interact with a live terminal multiplexer outside the workspace sandbox. Run Zellij inspection, read, and write commands with `sandbox_permissions: "require_escalated"` and a concise `justification` asking to allow access to the live Zellij session.

## Variables

- `SESSION="${SESSION:-work}"`
- `TARGET="${TARGET:-tests}"`
- `LINES="${LINES:-120}"`

## Inspect Session Structure First

Use these before acting:

- `zellij --session "$SESSION" action list-tabs --all --json`
- `zellij --session "$SESSION" action list-panes --all --json`
- `zellij --session "$SESSION" action dump-layout`

Compact pane map:

- `zellij --session "$SESSION" action list-panes --all --json | jq -r '.[] | select(.is_plugin == false) | "pane_id=terminal_\(.id) tab=\(.tab_name) title=\(.title) cmd=\(.pane_command // "-") cwd=\(.pane_cwd // "-") focused=\(.is_focused)"'`

Resolve a human target such as `tests`, `server`, or `logs`:

- `PANE_ID="$(zellij --session "$SESSION" action list-panes --all --json | jq -r --arg q "$TARGET" '.[] | select(.is_plugin == false) | select(((.title // "") | ascii_downcase | contains($q | ascii_downcase)) or ((.tab_name // "") | ascii_downcase | contains($q | ascii_downcase)) or ((.pane_command // "") | ascii_downcase | contains($q | ascii_downcase)) or ((.pane_cwd // "") | ascii_downcase | contains($q | ascii_downcase))) | "terminal_\(.id)"' | head -n 1)"`

Safety check:

- `test -n "$PANE_ID" || { echo "No matching Zellij pane: $TARGET" >&2; exit 1; }`

## Send Input To A Specific Pane

Send a command and press Enter:

- `COMMAND="cargo test"`
- `zellij --session "$SESSION" action paste --pane-id "$PANE_ID" "$COMMAND" && zellij --session "$SESSION" action send-keys --pane-id "$PANE_ID" "Enter"`

Send special keys:

- `zellij --session "$SESSION" action send-keys --pane-id "$PANE_ID" "Ctrl c"`
- `zellij --session "$SESSION" action send-keys --pane-id "$PANE_ID" "Enter"`
- `zellij --session "$SESSION" action send-keys --pane-id "$PANE_ID" "Esc"`

Use `paste` for normal text and commands.
Use `send-keys` for control keys.

## Read The Last N Lines From A Specific Pane

Read plain output:

- `zellij --session "$SESSION" action dump-screen --pane-id "$PANE_ID" --full | tail -n "$LINES"`

Read with ANSI color codes preserved:

- `zellij --session "$SESSION" action dump-screen --pane-id "$PANE_ID" --full --ansi | tail -n "$LINES"`

Examples:

- To read logs: set `TARGET=logs`, resolve `PANE_ID`, then run `dump-screen --full | tail`.
- To read tests: set `TARGET=tests`, resolve `PANE_ID`, then run `dump-screen --full | tail`.

## Workflow

When the human asks to interact with Zellij:

1. Run `list-tabs --all --json` and `list-panes --all --json` with escalated permissions.
2. Pick the correct `PANE_ID` from title, tab name, command, or cwd.
3. Use `paste` / `send-keys` to send one command or key sequence, again with escalated permissions.
4. Read the pane with `dump-screen --full | tail -n N` and inspect the result before sending the next input.
5. Continue interactively until the requested task is complete.

Do not send destructive keys such as `Ctrl c` unless the target pane is unambiguous.
