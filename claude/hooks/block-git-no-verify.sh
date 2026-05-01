#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Split on shell operators (||, &&, ;, |, &) so that `-n` flags passed to
# downstream commands (e.g. `git log | head -n 10`, `git ... | bash -n`)
# don't match the git --no-verify / -n flag.
segments=$(printf '%s' "$command" | sed -E 's/(\|\||&&|;|\||&)/\n/g')

while IFS= read -r seg; do
  seg=$(printf '%s' "$seg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  if printf '%s' "$seg" | grep -Eq '^git[[:space:]]' \
    && printf '%s' "$seg" | grep -Eq '(--no-verify|(^|[[:space:]])-n([[:space:]]|$))'; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "--no-verify / -n は禁止です。pre-commit hookをパスするように修正してください。"
      }
    }'
    exit 0
  fi
done <<< "$segments"

exit 0
