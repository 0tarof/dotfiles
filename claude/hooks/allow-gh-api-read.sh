#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command')

# Get the owner of the current repository
owner=$(git remote get-url origin 2>/dev/null | sed -E 's#.+[:/]([^/]+)/[^/]+(\.git)?$#\1#')
if [ -z "$owner" ]; then
  exit 0
fi

is_read=false
is_same_owner=false

if echo "$command" | grep -q 'graphql'; then
  # GraphQL: allow only queries (not mutations)
  if ! echo "$command" | grep -qi 'mutation'; then
    is_read=true
  fi
  # Check owner in -f owner=... or -F owner=...
  if echo "$command" | grep -Eq -- "(-f|-F)\s+owner=['\"]?${owner}['\"]?(\s|$)"; then
    is_same_owner=true
  fi
else
  # REST API: allow only GET (no -X or -X GET, no --method or --method GET)
  if echo "$command" | grep -Eq -- '-X\s*(POST|PUT|DELETE|PATCH)|--method\s*(POST|PUT|DELETE|PATCH)'; then
    is_read=false
  else
    is_read=true
  fi
  # Check if URL contains repos/{owner}/
  if echo "$command" | grep -q "repos/${owner}/"; then
    is_same_owner=true
  fi
fi

if [ "$is_read" = true ] && [ "$is_same_owner" = true ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "read-only gh api request to same-owner repository"
    }
  }'
fi

exit 0
