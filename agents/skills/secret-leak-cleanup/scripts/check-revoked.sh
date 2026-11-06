#!/bin/bash
set -euo pipefail

# 履歴中の Slack Webhook URL に空ペイロードを POST し、失効済みか判定する（投稿はされない）。
# 先頭 50 文字だけ表示する。404/no_service=失効済み、400/no_text・invalid_payload=生存。
# 引数に正規表現を渡すと Slack 以外の URL も対象にできる。

regex=${1:-'https://hooks\.slack\.com/(services|workflows)/[A-Za-z0-9/_-]+'}

{ git log --all -p | grep -Eo "$regex" || true; } | sort -u | while read -r u; do
  printf '%s... -> ' "${u:0:50}"
  curl -s -m 10 -X POST -H 'Content-Type: application/json' -d '{}' \
    -w ' [HTTP %{http_code}]\n' "$u"
done
