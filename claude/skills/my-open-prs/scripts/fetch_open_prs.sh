#!/usr/bin/env bash
set -euo pipefail

# Fetch open PRs authored by the authenticated user in a given org.
# Excludes drafts and archived repos by default.
#
# Usage: fetch_open_prs.sh [--org ORG] [--include-drafts] [--include-archived]
# Output: JSON array sorted by total diff size (ascending)

ORG="ajainc"
INCLUDE_DRAFTS=false
INCLUDE_ARCHIVED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org) ORG="$2"; shift 2 ;;
    --include-drafts) INCLUDE_DRAFTS=true; shift ;;
    --include-archived) INCLUDE_ARCHIVED=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Step 1: Fetch all open PRs
PRS=$(gh search prs --author=@me --owner="$ORG" --state=open \
  --json repository,number,title,isDraft,url --limit 100)

# Step 2: Filter drafts
if [ "$INCLUDE_DRAFTS" = "false" ]; then
  PRS=$(echo "$PRS" | jq '[.[] | select(.isDraft == false)]')
fi

# Step 3: Get unique repos and check archived status
if [ "$INCLUDE_ARCHIVED" = "false" ]; then
  REPOS=$(echo "$PRS" | jq -r '[.[].repository.nameWithOwner] | unique[]')
  ARCHIVED_REPOS=""
  for repo in $REPOS; do
    archived=$(gh api "repos/${repo}" --jq '.archived' 2>/dev/null || echo "false")
    if [ "$archived" = "true" ]; then
      ARCHIVED_REPOS="${ARCHIVED_REPOS}${repo}\n"
    fi
  done

  if [ -n "$ARCHIVED_REPOS" ]; then
    ARCHIVED_JSON=$(printf '%s' "$ARCHIVED_REPOS" | grep -v '^$' | jq -R -s 'split("\n") | map(select(. != ""))')
    PRS=$(echo "$PRS" | jq --argjson archived "$ARCHIVED_JSON" \
      '[.[] | select([.repository.nameWithOwner] | inside($archived) | not)]')
  fi
fi

# Step 4: Enrich with diff stats (additions/deletions)
LENGTH=$(echo "$PRS" | jq 'length')

if [ "$LENGTH" -eq 0 ]; then
  echo "[]"
  exit 0
fi

RESULT="[]"
for i in $(seq 0 $((LENGTH - 1))); do
  PR=$(echo "$PRS" | jq ".[$i]")
  REPO=$(echo "$PR" | jq -r '.repository.nameWithOwner')
  NUM=$(echo "$PR" | jq -r '.number')

  DIFF=$(gh pr view "$NUM" --repo "$REPO" --json additions,deletions \
    --jq '"\(.additions)\t\(.deletions)"' 2>/dev/null || echo "0\t0")
  ADD=$(echo "$DIFF" | cut -f1)
  DEL=$(echo "$DIFF" | cut -f2)
  TOTAL=$((ADD + DEL))

  RESULT=$(echo "$RESULT" | jq --argjson pr "$PR" \
    --argjson add "$ADD" --argjson del "$DEL" --argjson total "$TOTAL" \
    '. + [$pr + {additions: $add, deletions: $del, total_changes: $total}]')
done

# Step 5: Sort by total_changes ascending and output
echo "$RESULT" | jq 'sort_by(.total_changes)'
