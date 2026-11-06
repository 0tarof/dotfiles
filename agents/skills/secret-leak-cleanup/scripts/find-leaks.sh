#!/bin/bash
set -euo pipefail

# 認証情報の正規表現が残るコミット数と、それを含む PR を数える。値そのものは出力しない。
# usage: find-leaks.sh <regex> [--fetch-prs]

regex=${1:?usage: find-leaks.sh <regex> [--fetch-prs]}
[[ ${2:-} == --fetch-prs ]] && git fetch -q origin '+refs/pull/*/head:refs/pull/*/head'

shas=$(git log --all -G"$regex" --format=%H)
echo "commits: $(printf '%s' "$shas" | grep -c . || true)"
[[ -z "$shas" ]] && exit 0

echo "$shas" | while read -r sha; do
  git for-each-ref --contains "$sha" --format='%(refname)' refs/pull
done | sort -u | sed 's|refs/pull/||; s|/head$||' | { echo "pull refs:"; cat; }
echo "SHAs:"
echo "$shas"
