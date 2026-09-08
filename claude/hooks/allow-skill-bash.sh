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
if printf '%s' "$command" | grep -qE '[|;&<>]|`|\$\('; then
  exit 0
fi
# 改行を含むコマンドも拒否
if [ "$(printf '%s' "$command" | wc -l)" -gt 0 ]; then
  exit 0
fi

# argv[0] がインタプリタ/ラッパー系コマンドの場合は拒否
# (bash script.sh のように迂回して glob マッチを騙るのを防ぐ)
first_word=$(printf '%s' "$command" | awk '{print $1}')
case "$first_word" in
  bash|sh|zsh|env|command|eval|exec|xargs|sudo|nohup|time|nice)
    exit 0
    ;;
esac

SKILLS_DIR="$HOME/.claude/skills"
[ -d "$SKILLS_DIR" ] || exit 0

# glob パターンを正規表現に変換 (先頭が * でないパターン用)
glob_to_regex() {
  local pattern="$1"
  pattern="${pattern//\*/__GLOB_STAR__}"
  pattern=$(printf '%s' "$pattern" | sed 's/[.[\^$+?{}|()]/\\&/g')
  pattern="${pattern//__GLOB_STAR__/.*}"
  printf '%s' "$pattern"
}

# 先頭が * のパターン (例: *sync_pr_branch.py *) は
# 「スキル自身のスクリプトを argv[0] として実行しているか」に解決する。
# コマンド全体への前方一致を許してはならない。
match_leading_star_pattern() {
  local pattern="$1" skill_dir="$2" resolved_dir="$3"
  # 末尾のパターンからスクリプト名部分を取り出す (例: *sync_pr_branch.py * -> sync_pr_branch.py)
  local script_name="${pattern#\*}"
  script_name="${script_name% \*}"
  script_name="${script_name%\*}"

  # argv[0] がそのスクリプト名で終わっているか (パスの一部として、または完全一致)
  case "$first_word" in
    */"$script_name"|"$script_name")
      ;;
    *)
      return 1
      ;;
  esac

  # argv[0] を解決し、スキルディレクトリ配下の実在ファイルであることを確認
  local candidate
  case "$first_word" in
    /*) candidate="$first_word" ;;
    *) candidate="$skill_dir/$first_word" ;;
  esac
  [ -e "$candidate" ] || return 1

  local resolved_script
  resolved_script=$(readlink -f "$candidate" 2>/dev/null) || return 1

  case "$resolved_script" in
    "$resolved_dir"/*|"$resolved_dir")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# 全スキルのSKILL.mdからallowed-toolsのBashパターンを抽出してマッチ
matched=false
while IFS= read -r skill_file; do
  # first-party (Home Manager管理) のスキルのみ信頼する:
  # SKILL.md が /nix/store/ を指すシンボリックリンクであること
  resolved_skill_md=$(readlink -f "$skill_file" 2>/dev/null) || continue
  case "$resolved_skill_md" in
    /nix/store/*) ;;
    *) continue ;;
  esac

  skill_dir=$(dirname "$skill_file")

  patterns=$(awk '/^---$/{c++; next} c==1' "$skill_file" \
    | grep -oE 'Bash\([^)]+\)' \
    | sed 's/^Bash(//; s/)$//' \
    | sed 's/:\*/\ \*/' || true)

  [ -z "$patterns" ] && continue

  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue

    if [ "${pattern:0:1}" = "*" ]; then
      resolved_dir=$(dirname "$resolved_skill_md")
      if match_leading_star_pattern "$pattern" "$skill_dir" "$resolved_dir"; then
        matched=true
        break 2
      fi
      continue
    fi

    regex=$(glob_to_regex "$pattern")
    if printf '%s' "$command" | grep -qE "^${regex}$"; then
      matched=true
      break 2
    fi
  done <<< "$patterns"
done < <(find "$SKILLS_DIR" -name "SKILL.md" 2>/dev/null)

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
