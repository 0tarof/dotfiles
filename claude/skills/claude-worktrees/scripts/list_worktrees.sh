#!/usr/bin/env bash
set -euo pipefail

# List all git worktrees with their branches, associated PRs, and Claude session info.
# Outputs JSON array for easy consumption.

CLAUDE_PROJECTS_DIR="${HOME}/.claude/projects"

# Encode a filesystem path the same way Claude Code does for ~/.claude/projects/
encode_path() {
  echo "$1" | sed 's|/|-|g; s|\.|-|g'
}

# Get current repo's default remote org/repo (for gh queries)
# Fall back gracefully if not in a GitHub repo.
repo_slug() {
  gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo ""
}

REPO_SLUG="$(repo_slug)"

# Detect whether the current working directory is the main worktree.
# When true, we skip the main worktree entry in the final output because
# the user already knows what's happening there.
CURRENT_WT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
MAIN_WT="$(git worktree list --porcelain | awk '/^worktree / {print substr($0, 10); exit}')"
IS_CURRENT_MAIN="false"
if [[ -n "$CURRENT_WT" && "$CURRENT_WT" == "$MAIN_WT" ]]; then
  IS_CURRENT_MAIN="true"
fi

# Parse `git worktree list --porcelain` output into worktree blocks.
# Output format: <path>\t<branch>\t<is_main>
# The first entry in porcelain output is always the main worktree.
parse_worktrees() {
  git worktree list --porcelain | awk '
    BEGIN { wt=""; br=""; det=0; idx=0 }
    /^worktree / { wt=substr($0, 10) }
    /^branch / { br=substr($0, 19) }
    /^detached/ { det=1 }
    /^$/ {
      if (wt != "") {
        is_main = (idx == 0) ? "true" : "false"
        branch_out = (det == 1) ? "(detached)" : br
        print wt "\t" branch_out "\t" is_main
        idx++
      }
      wt=""; br=""; det=0
    }
    END {
      if (wt != "") {
        is_main = (idx == 0) ? "true" : "false"
        branch_out = (det == 1) ? "(detached)" : br
        print wt "\t" branch_out "\t" is_main
      }
    }
  '
}

# For a given branch, list PRs via gh (head match).
# Returns JSON array (possibly empty).
prs_for_branch() {
  local branch="$1"
  if [[ -z "$REPO_SLUG" || "$branch" == "(detached)" ]]; then
    echo "[]"
    return
  fi
  gh pr list \
    --repo "$REPO_SLUG" \
    --head "$branch" \
    --state all \
    --json number,title,url,state,isDraft \
    --limit 10 \
    2>/dev/null || echo "[]"
}

# For a given worktree path, gather Claude session info.
# Returns JSON { "dir": "...", "exists": bool, "session_count": N, "latest_session_id": "...", "latest_mtime": "..." }
claude_sessions_for_path() {
  local wt_path="$1"
  local encoded
  encoded="$(encode_path "$wt_path")"
  local session_dir="${CLAUDE_PROJECTS_DIR}/${encoded}"

  if [[ ! -d "$session_dir" ]]; then
    jq -n --arg dir "$session_dir" '{dir: $dir, exists: false, session_count: 0, latest_session_id: null, latest_mtime: null}'
    return
  fi

  local count latest_file latest_id latest_mtime
  count=$(find "$session_dir" -maxdepth 1 -name '*.jsonl' -type f 2>/dev/null | wc -l | tr -d ' ')
  latest_file=$(ls -t "$session_dir"/*.jsonl 2>/dev/null | head -1 || true)

  if [[ -n "$latest_file" ]]; then
    latest_id="$(basename "$latest_file" .jsonl)"
    latest_mtime="$(date -r "$latest_file" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")"
  else
    latest_id=""
    latest_mtime=""
  fi

  jq -n \
    --arg dir "$session_dir" \
    --argjson count "$count" \
    --arg latest_id "$latest_id" \
    --arg latest_mtime "$latest_mtime" \
    '{
      dir: $dir,
      exists: true,
      session_count: $count,
      latest_session_id: (if $latest_id == "" then null else $latest_id end),
      latest_mtime: (if $latest_mtime == "" then null else $latest_mtime end)
    }'
}

# Build the final JSON array. Only include worktrees that have at least one
# Claude Code session ("active" worktrees).
results="[]"
while IFS=$'\t' read -r wt_path branch is_main; do
  [[ -z "$wt_path" ]] && continue
  # Skip the main worktree entry when the user is currently sitting in it.
  if [[ "$IS_CURRENT_MAIN" == "true" && "$is_main" == "true" ]]; then
    continue
  fi
  claude_info="$(claude_sessions_for_path "$wt_path")"
  has_session=$(jq -r '.session_count > 0' <<<"$claude_info")
  [[ "$has_session" != "true" ]] && continue

  prs="$(prs_for_branch "$branch")"
  wt_name="$(basename "$wt_path")"
  entry=$(jq -n \
    --arg path "$wt_path" \
    --arg branch "$branch" \
    --arg wt_name "$wt_name" \
    --argjson is_main "$is_main" \
    --argjson prs "$prs" \
    --argjson claude "$claude_info" \
    '{path: $path, branch: $branch, worktree_name: $wt_name, is_main: $is_main, prs: $prs, claude: $claude}')
  results=$(jq --argjson e "$entry" '. + [$e]' <<<"$results")
done < <(parse_worktrees)

echo "$results"
