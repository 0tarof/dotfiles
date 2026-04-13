#!/usr/bin/env bash
set -euo pipefail

# Fetch today's GitHub activity for the authenticated user and output as JSON.

TODAY=$(date -u +%Y-%m-%d)
TOMORROW=$(date -u -v+1d +%Y-%m-%d 2>/dev/null || date -u -d "+1 day" +%Y-%m-%d)
USERNAME=$(gh api /user --jq .login)

# Fetch all events for today (GitHub Events API returns max 300 events / 10 pages)
ALL_EVENTS=$(gh api "/users/${USERNAME}/events" --paginate --jq \
  ".[] | select(.created_at >= \"${TODAY}T00:00:00Z\" and .created_at < \"${TOMORROW}T00:00:00Z\")")

# If no events, output empty summary
if [ -z "$ALL_EVENTS" ]; then
  jq -n \
    --arg date "$TODAY" \
    --arg user "$USERNAME" \
    '{
      date: $date,
      user: $user,
      summary: {
        total_events: 0,
        prs_merged: [],
        prs_opened: [],
        prs_reviewed: [],
        issues_opened: [],
        issues_closed: [],
        comments: [],
        pushes: []
      }
    }'
  exit 0
fi

EVENTS_ARRAY=$(echo "$ALL_EVENTS" | jq -s '.')
TOTAL_EVENTS=$(echo "$EVENTS_ARRAY" | jq 'length')

# Extract PullRequestEvent
PRS_MERGED=$(echo "$EVENTS_ARRAY" | jq '[.[] | select(.type == "PullRequestEvent" and .payload.action == "closed" and .payload.pull_request.merged == true) | {repo: .repo.name, number: .payload.pull_request.number, title: .payload.pull_request.title, action: "merged"}]')
PRS_OPENED=$(echo "$EVENTS_ARRAY" | jq '[.[] | select(.type == "PullRequestEvent" and .payload.action == "opened") | {repo: .repo.name, number: .payload.pull_request.number, title: .payload.pull_request.title, action: "opened"}]')

# Extract PullRequestReviewEvent (approved / changes_requested only)
PRS_REVIEWED=$(echo "$EVENTS_ARRAY" | jq '[.[] | select(.type == "PullRequestReviewEvent" and (.payload.review.state == "approved" or .payload.review.state == "changes_requested")) | {repo: .repo.name, number: .payload.pull_request.number, title: .payload.pull_request.title, review_state: .payload.review.state}]')

# Extract IssuesEvent
ISSUES_OPENED=$(echo "$EVENTS_ARRAY" | jq '[.[] | select(.type == "IssuesEvent" and .payload.action == "opened") | {repo: .repo.name, number: .payload.issue.number, title: .payload.issue.title, action: "opened"}]')
ISSUES_CLOSED=$(echo "$EVENTS_ARRAY" | jq '[.[] | select(.type == "IssuesEvent" and .payload.action == "closed") | {repo: .repo.name, number: .payload.issue.number, title: .payload.issue.title, action: "closed"}]')

# Extract IssueCommentEvent
COMMENTS=$(echo "$EVENTS_ARRAY" | jq '[.[] | select(.type == "IssueCommentEvent") | {repo: .repo.name, number: .payload.issue.number, title: .payload.issue.title, action: "commented"}]')

# Extract PushEvent
PUSHES=$(echo "$EVENTS_ARRAY" | jq '[.[] | select(.type == "PushEvent") | {repo: .repo.name, ref: .payload.ref}]')

# Title complement function: fill null titles from PR/Issue via gh API
complement_titles() {
  local json="$1"
  local kind="$2" # "pr" or "issue"
  local length
  length=$(echo "$json" | jq 'length')

  if [ "$length" -eq 0 ]; then
    echo "$json"
    return
  fi

  local result="$json"
  for i in $(seq 0 $((length - 1))); do
    local title
    title=$(echo "$json" | jq -r ".[$i].title // empty")
    if [ -z "$title" ]; then
      local repo number fetched_title
      repo=$(echo "$json" | jq -r ".[$i].repo")
      number=$(echo "$json" | jq -r ".[$i].number")
      if [ "$kind" = "pr" ]; then
        fetched_title=$(gh pr view "$number" --repo "$repo" --json title --jq .title 2>/dev/null || echo "")
      else
        fetched_title=$(gh issue view "$number" --repo "$repo" --json title --jq .title 2>/dev/null || echo "")
      fi
      if [ -n "$fetched_title" ]; then
        result=$(echo "$result" | jq --argjson idx "$i" --arg title "$fetched_title" '.[$idx].title = $title')
      fi
    fi
  done
  echo "$result"
}

# Complement null titles
PRS_MERGED=$(complement_titles "$PRS_MERGED" "pr")
PRS_OPENED=$(complement_titles "$PRS_OPENED" "pr")
PRS_REVIEWED=$(complement_titles "$PRS_REVIEWED" "pr")
ISSUES_OPENED=$(complement_titles "$ISSUES_OPENED" "issue")
ISSUES_CLOSED=$(complement_titles "$ISSUES_CLOSED" "issue")
COMMENTS=$(complement_titles "$COMMENTS" "issue")

# Build final JSON output
jq -n \
  --arg date "$TODAY" \
  --arg user "$USERNAME" \
  --argjson total "$TOTAL_EVENTS" \
  --argjson prs_merged "$PRS_MERGED" \
  --argjson prs_opened "$PRS_OPENED" \
  --argjson prs_reviewed "$PRS_REVIEWED" \
  --argjson issues_opened "$ISSUES_OPENED" \
  --argjson issues_closed "$ISSUES_CLOSED" \
  --argjson comments "$COMMENTS" \
  --argjson pushes "$PUSHES" \
  '{
    date: $date,
    user: $user,
    summary: {
      total_events: $total,
      prs_merged: $prs_merged,
      prs_opened: $prs_opened,
      prs_reviewed: $prs_reviewed,
      issues_opened: $issues_opened,
      issues_closed: $issues_closed,
      comments: $comments,
      pushes: $pushes
    }
  }'
