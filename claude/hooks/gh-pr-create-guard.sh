#!/usr/bin/env bash
# `gh pr create` を --web 以外で実行しようとしたら必ず確認プロンプトを出す PreToolUse フック。
# --web は pr-create スキル経由の正規ルートなので素通しする。
#
# Why: permissions.ask に `gh pr create` を入れると --web まで巻き込まれてしまい、
# 評価順が deny > ask > allow（先勝ち）なので allow では除外できない。条件分岐できる
# フックでのみ「--web を含むときだけ素通す」carve-out が実現できる。
set -euo pipefail

command=$(jq -r '.tool_input.command // empty')
[ -z "$command" ] && exit 0

# 複合コマンド（cd x && gh pr create 等）や区切り文字直後も拾うため境界を明示。
if printf '%s' "$command" | grep -Eq '(^|[[:space:]]|[;&|(])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'; then
  if ! printf '%s' "$command" | grep -Eq '(^|[[:space:]])--web([[:space:]]|$)'; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: "gh pr create は --web を除き、毎回ユーザーの明示的な確認が必要です"
      }
    }'
  fi
fi

exit 0
