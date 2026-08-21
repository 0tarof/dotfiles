#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Quick exit if the command doesn't mention the service at all
if ! printf '%s' "$command" | grep -qi 'secretsmanager'; then
  exit 0
fi

# Flatten line continuations, quotes and shell operators so that a command
# split across lines (`aws secretsmanager \` + newline + `get-secret-value`),
# quoted piecewise (`get-secret-'value'`) or buried in a pipe / subshell
# (`$(aws secretsmanager get-secret-value ...)`) still yields plain tokens.
normalized=$(printf '%s' "$command" \
  | tr '\n\t' '  ' \
  | tr -d '\\"' \
  | tr -d "'" \
  | sed -E 's/[|&;(){}`]/ /g' \
  | tr -s ' ')

# Require both the service token and a value-returning subcommand, so that
# describe-secret / list-secrets / get-random-password stay untouched.
if printf '%s' "$normalized" | grep -Eqi '(^|[[:space:]])secretsmanager([[:space:]]|$)' \
  && printf '%s' "$normalized" | grep -Eqi '(^|[[:space:]])(batch-)?get-secret-value([[:space:]]|$)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "aws secretsmanager get-secret-value / batch-get-secret-value によるシークレット値の読み出しは禁止です。「読み取りだから軽い」という判断は認められません。メタデータが必要な場合は describe-secret / list-secrets を使ってください。値そのものが必要な場合は、勝手に取得せずユーザーに依頼してください（ユーザー自身がターミナルで取得します）。"
    }
  }'
  exit 0
fi

exit 0
