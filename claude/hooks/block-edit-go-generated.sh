#!/bin/bash
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')

is_generated() {
  local file="$1"
  [[ -f "$file" ]] && head -10 "$file" | grep -q "Code generated .* DO NOT EDIT"
}

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
}

case "$tool_name" in
  Edit|Write|Update)
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
    if [[ "$file_path" == *.go ]] && is_generated "$file_path"; then
      deny "自動生成された Go ファイルの編集は禁止です。生成元を修正して再生成してください。"
    fi
    ;;
  Bash)
    command=$(echo "$input" | jq -r '.tool_input.command // empty')
    # sed コマンドから .go ファイルパスを抽出してチェック
    for file in $(echo "$command" | grep -oE '[^ "'"'"']+\.go'); do
      if is_generated "$file"; then
        deny "自動生成された Go ファイルの編集は禁止です。生成元を修正して再生成してください。"
        break
      fi
    done
    ;;
esac

exit 0
