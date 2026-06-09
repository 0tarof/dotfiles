#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Split on shell operators (||, &&, ;, |, &) so that a banned `git add`
# in a compound command (e.g. `foo && git add -A`) is still detected and a
# `.` belonging to a different command doesn't cause a false positive.
segments=$(printf '%s' "$command" | sed -E 's/(\|\||&&|;|\||&)/\n/g')

while IFS= read -r seg; do
  seg=$(printf '%s' "$seg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  # Only inspect `git add ...` segments
  if printf '%s' "$seg" | grep -Eq '^git[[:space:]]+add([[:space:]]|$)'; then
    # Bulk staging forms: -A / --all / `.` (standalone, not ./path)
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])(-A|--all)([[:space:]]|$)' \
      || printf '%s' "$seg" | grep -Eq '(^|[[:space:]])\.([[:space:]]|$)'; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: "git add -A / git add . / git add --all は禁止です。意図しないファイル（シークレット・ビルド成果物・スコープ外）を巻き込む危険があるため、対象パスを明示して個別に add してください（例: git add path/to/file1 path/to/file2）。"
        }
      }'
      exit 0
    fi
  fi
done <<< "$segments"

exit 0
