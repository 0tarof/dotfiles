#!/bin/bash
set -euo pipefail

# Claude Code の権限・フック設定ファイルをエージェント自身が書き換えられないようにするガード。
# defaultMode: acceptEdits では Edit/Write が自動承認されるため、
# settings.json や hooks/ 配下のスクリプトを書き換えて自身の制約を外すバイパスを防ぐ。

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[ -z "$file_path" ] && exit 0

# ~ 展開
case "$file_path" in
  "~"|"~/"*)
    file_path="${HOME}${file_path#\~}"
    ;;
esac

# 相対パスは CLAUDE_WORKING_DIRECTORY (なければ PWD) を基準に絶対化
case "$file_path" in
  /*) ;;
  *)
    base_dir="${CLAUDE_WORKING_DIRECTORY:-$PWD}"
    file_path="${base_dir%/}/${file_path}"
    ;;
esac

resolved_path=$(readlink -f "$file_path" 2>/dev/null || printf '%s' "$file_path")

REPO_DIR="$HOME/projects/github.com/0tarof/dotfiles"

protected_raw=(
  "$HOME/.claude/settings.json"
  "$HOME/.claude/settings.local.json"
  "$REPO_DIR/claude/settings.json"
)

is_protected=false

for p in "${protected_raw[@]}"; do
  p_resolved=$(readlink -f "$p" 2>/dev/null || printf '%s' "$p")
  if [ "$file_path" = "$p" ] || [ "$resolved_path" = "$p" ] || \
     [ "$file_path" = "$p_resolved" ] || [ "$resolved_path" = "$p_resolved" ]; then
    is_protected=true
    break
  fi
done

if [ "$is_protected" = false ]; then
  hooks_dirs_raw=(
    "$HOME/.claude/hooks"
    "$REPO_DIR/claude/hooks"
  )
  for d in "${hooks_dirs_raw[@]}"; do
    d_resolved=$(readlink -f "$d" 2>/dev/null || printf '%s' "$d")
    case "$file_path" in
      "$d"/*|"$d_resolved"/*)
        is_protected=true
        break
        ;;
    esac
    case "$resolved_path" in
      "$d"/*|"$d_resolved"/*)
        is_protected=true
        break
        ;;
    esac
  done
fi

if [ "$is_protected" = true ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Claude Code の権限・フック設定はエージェントから変更できません。ユーザーが手で編集してください。"
    }
  }'
  exit 0
fi

exit 0
