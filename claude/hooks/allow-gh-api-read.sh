#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command')

# Get the owner of the current repository
owner=$(git remote get-url origin 2>/dev/null | sed -E 's#.+[:/]([^/]+)/[^/]+(\.git)?$#\1#')
if [ -z "$owner" ]; then
  exit 0
fi

# 引用符が含まれる場合は空白分割による誤判定のリスクがあるため、安全側に倒して no-opinion
if printf '%s' "$command" | grep -q "['\"]"; then
  # ただし graphql の -f query='...' は引用符を伴うのが通常なので、
  # そのケースのみ別ロジックで許可判定を行う (owner/mutation チェックは文字列全体に対して行う)
  if ! printf '%s' "$command" | grep -qE '(^|[[:space:]])gh[[:space:]]+api[[:space:]]+graphql([[:space:]]|$)'; then
    exit 0
  fi
fi

# コマンドを単純に空白でトークン化
read -r -a tokens <<< "$command"

# "gh api" の位置を探す
gh_idx=-1
api_idx=-1
for i in "${!tokens[@]}"; do
  if [ "${tokens[$i]}" = "gh" ] && [ "$((i + 1))" -lt "${#tokens[@]}" ] && [ "${tokens[$((i + 1))]}" = "api" ]; then
    gh_idx=$i
    api_idx=$((i + 1))
    break
  fi
done

if [ "$api_idx" -lt 0 ]; then
  exit 0
fi

is_graphql=false
if [ "$((api_idx + 1))" -lt "${#tokens[@]}" ] && [ "${tokens[$((api_idx + 1))]}" = "graphql" ]; then
  is_graphql=true
fi

is_read=true
is_same_owner=false
has_hostname=false
endpoint=""
positional_count=0

# 大文字小文字を問わず GET かどうかを判定する (bash 3.2 互換)
is_get_method() {
  case "$1" in
    [Gg][Ee][Tt]) return 0 ;;
    *) return 1 ;;
  esac
}

if [ "$is_graphql" = true ]; then
  # mutation キーワードが含まれていれば書き込みとみなす
  if printf '%s' "$command" | grep -qi 'mutation'; then
    is_read=false
  fi
  # --input はサポート外の入力方法なので拒否
  # -F / --field はファイル読み込み (@path) や環境変数展開に使えるため拒否
  for t in "${tokens[@]}"; do
    case "$t" in
      --input|--input=*|-F|--field|--field=*)
        is_read=false
        ;;
      --hostname|--hostname=*)
        has_hostname=true
        ;;
      http://*|https://*)
        has_hostname=true
        ;;
    esac
  done
  # -f owner=... を確認 (-F は上で拒否済み)
  if printf '%s' "$command" | grep -Eq -- "-f[[:space:]]+owner=['\"]?${owner}['\"]?([[:space:]]|\$)"; then
    is_same_owner=true
  fi
else
  # 最初の非フロートークン (api の次) をエンドポイントとみなす
  # フラグとその値を判定しつつ走査する
  i=$((api_idx + 1))
  n=${#tokens[@]}
  while [ "$i" -lt "$n" ]; do
    t="${tokens[$i]}"
    case "$t" in
      -f|-F|--field|--raw-field|--input)
        is_read=false
        i=$((i + 1))
        continue
        ;;
      --field=*|--raw-field=*|--input=*)
        is_read=false
        i=$((i + 1))
        continue
        ;;
      --hostname)
        has_hostname=true
        i=$((i + 2))
        continue
        ;;
      --hostname=*)
        has_hostname=true
        i=$((i + 1))
        continue
        ;;
      --method|--method=*|-X)
        method=""
        if [[ "$t" == --method=* ]]; then
          method="${t#--method=}"
        elif [ "$t" = "--method" ] || [ "$t" = "-X" ]; then
          i=$((i + 1))
          method="${tokens[$i]:-}"
        fi
        if [ -n "$method" ] && ! is_get_method "$method"; then
          is_read=false
        fi
        i=$((i + 1))
        continue
        ;;
      -X*)
        # -XPOST のような結合形式
        method="${t#-X}"
        if [ -n "$method" ] && ! is_get_method "$method"; then
          is_read=false
        fi
        i=$((i + 1))
        continue
        ;;
      -H|--header|-q|--jq|-t|--template|--cache|-p|--preview)
        # 値を1つ消費するフラグ
        i=$((i + 2))
        continue
        ;;
      --header=*|--jq=*|--template=*|--cache=*|--preview=*)
        i=$((i + 1))
        continue
        ;;
      http://*|https://*)
        has_hostname=true
        positional_count=$((positional_count + 1))
        if [ -z "$endpoint" ]; then
          endpoint="$t"
        fi
        i=$((i + 1))
        continue
        ;;
      -*)
        i=$((i + 1))
        continue
        ;;
      *)
        positional_count=$((positional_count + 1))
        if [ -z "$endpoint" ]; then
          endpoint="$t"
        fi
        i=$((i + 1))
        continue
        ;;
    esac
  done

  if [ "$positional_count" -eq 1 ] && [[ "$endpoint" =~ ^/?repos/${owner}/[^/]+(/.*)?$ ]]; then
    is_same_owner=true
  fi
fi

if [ "$has_hostname" = true ]; then
  exit 0
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
