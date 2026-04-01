#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command')

if echo "$command" | grep -qi 'mutation'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "gh api graphql with mutation detected — confirm before executing"
    }
  }'
fi

exit 0
