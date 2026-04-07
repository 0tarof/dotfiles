#!/bin/bash
set -euo pipefail

# allowed-tools バグのワークアラウンド (https://github.com/anthropics/claude-code/issues/14956)
# スキルの allowed-tools で Bash コマンドの承認バイパスが効かないため、
# 全スキルの allowed-tools からBashパターンを収集し、マッチするコマンドを自動承認する。

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command')

[ -z "$command" ] && exit 0

# セキュリティ: コマンド連結・インジェクション文字を含むコマンドは拒否
# パイプ、セミコロン、&&、||、バッククォート、$()を検出
if printf '%s' "$command" | grep -qE '[|;&]|`|\$\('; then
  exit 0
fi
# 改行を含むコマンドも拒否
if [ "$(printf '%s' "$command" | wc -l)" -gt 0 ]; then
  exit 0
fi

SKILLS_DIR="$HOME/.claude/skills"
[ -d "$SKILLS_DIR" ] || exit 0

# glob パターンを正規表現に変換
glob_to_regex() {
  local pattern="$1"
  # まず * を一時プレースホルダに置換
  pattern="${pattern//\*/__GLOB_STAR__}"
  # 正規表現の特殊文字をエスケープ
  pattern=$(printf '%s' "$pattern" | sed 's/[.[\^$+?{}|()]/\\&/g')
  # プレースホルダを .* に置換
  pattern="${pattern//__GLOB_STAR__/.*}"
  printf '%s' "$pattern"
}

# 全スキルのSKILL.mdからallowed-toolsのBashパターンを抽出してマッチ
matched=false
while IFS= read -r skill_file; do
  patterns=$(awk '/^---$/{n++; next} n==1' "$skill_file" \
    | grep -oE 'Bash\([^)]+\)' \
    | sed 's/^Bash(//; s/)$//' || true)

  [ -z "$patterns" ] && continue

  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    regex=$(glob_to_regex "$pattern")
    if printf '%s' "$command" | grep -qE "^${regex}$"; then
      matched=true
      break 2
    fi
  done <<< "$patterns"
done < <(find "$SKILLS_DIR" -name "SKILL.md" -type f 2>/dev/null)

if [ "$matched" = true ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "auto-approved by skill allowed-tools workaround"
    }
  }'
fi

exit 0
