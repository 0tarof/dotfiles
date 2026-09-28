#!/bin/bash
set -euo pipefail

# PR ブランチへ base ブランチを merge させないガード。長命な PR ブランチに merge
# commit が入ると GitHub 上の diff とレビュー履歴が追いにくくなるため、rebase に
# 誘導する。Claude Code (PreToolUse) と Cursor (beforeShellExecution) の両方から呼ぶ。

input=$(cat)
if printf '%s' "$input" | jq -e 'has("tool_input")' >/dev/null 2>&1; then
  agent=claude
  command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
else
  agent=cursor
  command=$(printf '%s' "$input" | jq -r '.command // empty')
fi

allow() {
  if [ "$agent" = cursor ]; then
    echo '{"permission":"allow"}'
  fi
  exit 0
}

deny() {
  local reason="base ブランチを merge せず rebase してください: git fetch origin && git rebase origin/<base> && git push --force-with-lease。merge commit が入ると PR の diff とレビュー履歴が追いにくくなります。"
  if [ "$agent" = cursor ]; then
    jq -n --arg r "$reason" '{permission: "deny", user_message: $r, agent_message: $r}'
  else
    jq -n --arg r "$reason" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $r
      }
    }'
  fi
  exit 0
}

[ -z "$command" ] && allow

base_ref='(origin/[^[:space:]]+|main|master|develop)'

segments=$(printf '%s' "$command" | sed -E 's/(\|\||&&|;|\||&)/\n/g')
while IFS= read -r seg; do
  seg=$(printf '%s' "$seg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

  if printf '%s' "$seg" | grep -Eq '^git[[:space:]]+merge([[:space:]]|$)'; then
    # 進行中の merge の後始末と、main 上での fast-forward は merge commit を作らない。
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])(--abort|--continue|--quit|--ff-only)([[:space:]]|$)'; then
      continue
    fi
    if printf '%s' "$seg" | grep -Eq "[[:space:]]${base_ref}([[:space:]]|\$)"; then
      deny
    fi
  fi

  # pull.rebase = true を明示的に打ち消す pull も同じ merge になる。
  if printf '%s' "$seg" | grep -Eq '^git[[:space:]]+pull([[:space:]].*)?[[:space:]](--no-rebase|--rebase=false)([[:space:]]|$)'; then
    deny
  fi
done <<< "$segments"

allow
