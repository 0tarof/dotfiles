#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[ -z "$command" ] && exit 0

tirith_bin="${TIRITH_BIN:-}"
if [ -z "$tirith_bin" ]; then
  tirith_bin="$(command -v tirith 2>/dev/null || true)"
fi

if [ -z "$tirith_bin" ] && [ -x "/etc/profiles/per-user/$USER/bin/tirith" ]; then
  tirith_bin="/etc/profiles/per-user/$USER/bin/tirith"
fi

if [ -z "$tirith_bin" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "tirith command not found; Bash command blocked for safety"
    }
  }'
  exit 0
fi

output_file="$(mktemp)"
status=0
"$tirith_bin" check --non-interactive --shell posix -- "$command" >"$output_file" 2>&1 || status=$?
output="$(cat "$output_file")"
rm -f "$output_file"

case "$status" in
  0)
    exit 0
    ;;
  1)
    jq -n --arg reason "$output" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    ;;
  2)
    jq -n --arg reason "$output" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: $reason
      }
    }'
    ;;
  *)
    jq -n --arg reason "tirith check failed with exit code ${status}: ${output}" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    ;;
esac

exit 0
