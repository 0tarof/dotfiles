#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

segments=$(printf '%s' "$command" | sed -E 's/(\|\||&&|;|\||&)/\n/g')

while IFS= read -r seg; do
  seg=$(printf '%s' "$seg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  if printf '%s' "$seg" | grep -Eq '^corepack([[:space:]]|$)'; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "corepack の実行は禁止です。パッケージマネージャは既存のインストール済みバイナリを直接使用してください。"
      }
    }'
    exit 0
  fi
done <<< "$segments"

exit 0
