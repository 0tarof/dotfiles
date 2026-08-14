#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

if echo "$command" | grep -Eq '(gh auth token|gh auth status.*--show-token|\$\(gh auth|\bGITHUB_TOKEN=.*\$\(|access-tokens.*=.*\$\(gh)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "gh token の取得・展開が含まれています。トークンが ps や環境変数経由で漏洩するリスクがあります。本当に実行しますか？"
    }
  }'
  exit 0
fi

exit 0
