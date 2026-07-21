#!/bin/bash
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')

cwd="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"

get_repo_id() {
  local dir="$1"
  [ -d "$dir" ] || return 1
  local common_dir
  common_dir=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
  if [[ "$common_dir" == /* ]]; then
    printf '%s' "$common_dir"
  else
    (cd "$dir/$common_dir" && pwd)
  fi
}

session_repo=$(get_repo_id "$cwd") || exit 0

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
}

resolve_path() {
  local p="$1"
  case "$p" in
    "~/"*) p="${HOME}${p:1}" ;;
    "~")   p="$HOME" ;;
  esac
  [[ "$p" != /* ]] && p="$cwd/$p"
  printf '%s' "$p"
}

is_other_repo() {
  local target
  target=$(resolve_path "$1")

  local dir
  if [ -d "$target" ]; then
    dir="$target"
  else
    dir=$(dirname "$target")
  fi

  local target_repo
  target_repo=$(get_repo_id "$dir") || return 1

  [ "$target_repo" != "$session_repo" ]
}

MSG="別のリポジトリで作業する場合は、そのリポジトリで Claude Code を起動してください。"

case "$tool_name" in
  Edit|Write)
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
    if [ -n "$file_path" ] && is_other_repo "$file_path"; then
      deny "他のリポジトリ内のファイル ($file_path) への書き込みはブロックされました。$MSG"
    fi
    ;;
  Bash)
    command=$(echo "$input" | jq -r '.tool_input.command // empty')

    if ! printf '%s' "$command" | grep -qE '(^|[[:space:]])(cd|pushd|git)[[:space:]]'; then
      exit 0
    fi

    segments=$(printf '%s' "$command" | sed -E 's/(\|\||&&|;|\||&)/\n/g')

    while IFS= read -r seg; do
      seg=$(printf '%s' "$seg" | sed 's/^[[:space:]({]*//; s/[[:space:])}]*$//')
      [ -z "$seg" ] && continue

      # cd / pushd
      if printf '%s' "$seg" | grep -Eq '^(cd|pushd)[[:space:]]+'; then
        path=$(printf '%s' "$seg" | sed -E "s/^(cd|pushd)[[:space:]]+//; s/['\"]//g")
        if [ -n "$path" ] && is_other_repo "$path"; then
          deny "他のリポジトリ ($path) への移動はブロックされました。$MSG"
          exit 0
        fi
      fi

      # git -C <path>
      if printf '%s' "$seg" | grep -Eq '^git[[:space:]]'; then
        path=$(printf '%s' "$seg" | grep -oE -- '-C[[:space:]]+[^[:space:]]+' | head -1 | sed 's/-C[[:space:]]*//' || true)
        if [ -n "$path" ] && is_other_repo "$path"; then
          deny "他のリポジトリ ($path) への git -C はブロックされました。$MSG"
          exit 0
        fi
      fi
    done <<< "$segments"
    ;;
esac

exit 0
