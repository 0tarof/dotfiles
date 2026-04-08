#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

if echo "$command" | grep -Eq "^git\s" && echo "$command" | grep -Eq "(--no-verify|(^|\s)-n(\s|$))"; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "--no-verify / -n は禁止です。pre-commit hookをパスするように修正してください。"
    }
  }'
fi

exit 0
