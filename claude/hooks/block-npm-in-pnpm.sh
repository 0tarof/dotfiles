#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Quick exit if command doesn't mention npm or npx
if ! printf '%s' "$command" | grep -qE '(^|[^a-z])n(pm|px)([[:space:]]|$)'; then
  exit 0
fi

segments=$(printf '%s' "$command" | sed -E 's/(\|\||&&|;|\||&)/\n/g')

effective_cwd="$PWD"
has_npm=false

while IFS= read -r seg; do
  seg=$(printf '%s' "$seg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

  # Track cd to follow directory changes
  if printf '%s' "$seg" | grep -Eq '^cd[[:space:]]+'; then
    target=$(printf '%s' "$seg" | sed 's/^cd[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [[ "${target:0:1}" == "/" ]]; then
      [[ -d "$target" ]] && effective_cwd="$target"
    else
      [[ -d "$effective_cwd/$target" ]] && effective_cwd="$effective_cwd/$target"
    fi
  fi

  if printf '%s' "$seg" | grep -Eq '^(npm|npx)([[:space:]]|$)'; then
    has_npm=true
    break
  fi
done <<< "$segments"

if ! "$has_npm"; then
  exit 0
fi

repo_root=$(cd "$effective_cwd" && git rev-parse --show-toplevel 2>/dev/null) || exit 0

if [[ -f "$repo_root/pnpm-lock.yaml" || -f "$repo_root/pnpm-workspace.yaml" ]]; then
  jq -n --arg reason "このリポジトリは pnpm で管理されています。npm/npx の代わりに pnpm / pnpm exec / pnpm dlx を使用してください。" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
fi
