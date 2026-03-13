#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command')

if echo "$command" | grep -qE '\-delete|-exec\s+rm'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "find with -delete or -exec rm is not allowed"
    }
  }'
fi

exit 0
