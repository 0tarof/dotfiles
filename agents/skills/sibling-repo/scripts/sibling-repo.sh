#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# sibling-repo helper: operate on repositories next to the current repo's main worktree.
#
# Usage:
#   sibling-repo.sh main                     - print the main worktree path
#   sibling-repo.sh siblings-dir             - print the directory that contains sibling repos
#   sibling-repo.sh list                     - list sibling repos with branch and latest commit
#   sibling-repo.sh path <repo>              - print a sibling repo absolute path
#   sibling-repo.sh status <repo>            - git status
#   sibling-repo.sh log <repo> [n]           - git log --oneline, default 10
#   sibling-repo.sh branch <repo>            - git branch -a
#   sibling-repo.sh fetch <repo>             - fetch the default branch
#   sibling-repo.sh pull <repo>              - pull the default branch
#   sibling-repo.sh ls <repo> [path]         - list files

ensure_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: current directory is not inside a Git worktree" >&2
    exit 1
  fi
}

resolve_main_worktree() {
  ensure_git_repo

  local main_worktree
  main_worktree=$(
    git worktree list --porcelain |
      awk '/^worktree / { print substr($0, 10); exit }'
  )

  if [[ -z "$main_worktree" ]]; then
    echo "Error: failed to resolve main worktree from git worktree list" >&2
    exit 1
  fi

  echo "$main_worktree"
}

resolve_siblings_dir() {
  local main_worktree
  main_worktree=$(resolve_main_worktree)
  dirname "$main_worktree"
}

is_git_repo_dir() {
  local dir="$1"
  [[ -d "$dir" ]] && git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

resolve_repo_path() {
  local siblings_dir="$1"
  local repo="$2"
  local repo_path="$siblings_dir/$repo"

  if ! is_git_repo_dir "$repo_path"; then
    echo "Error: '$repo' was not found as a sibling Git repository" >&2
    echo "Available repositories:" >&2
    list_repos "$siblings_dir" >&2
    exit 1
  fi

  echo "$repo_path"
}

get_default_branch() {
  local repo_path="$1"
  git -C "$repo_path" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null |
    sed 's@^refs/remotes/origin/@@' ||
    echo "main"
}

list_repos() {
  local siblings_dir="$1"
  local dir repo branch commit

  for dir in "$siblings_dir"/*/; do
    if is_git_repo_dir "$dir"; then
      repo=$(basename "$dir")
      branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "detached")
      if [[ -z "$branch" ]]; then
        branch="detached"
      fi
      commit=$(git -C "$dir" log --oneline -1 2>/dev/null || echo "no commits")
      echo "$repo  [$branch]  $commit"
    fi
  done
}

usage() {
  cat >&2 <<'EOF'
Usage: sibling-repo.sh {main|siblings-dir|list|path|status|log|branch|fetch|pull|ls} [args...]
EOF
}

CMD="${1:-list}"
shift || true

case "$CMD" in
  main | main-worktree)
    resolve_main_worktree
    ;;
  siblings-dir)
    resolve_siblings_dir
    ;;
  list)
    list_repos "$(resolve_siblings_dir)"
    ;;
  path)
    repo="${1:?Usage: sibling-repo.sh path <repo>}"
    resolve_repo_path "$(resolve_siblings_dir)" "$repo"
    ;;
  status)
    repo="${1:?Usage: sibling-repo.sh status <repo>}"
    repo_path=$(resolve_repo_path "$(resolve_siblings_dir)" "$repo")
    git -C "$repo_path" status
    ;;
  log)
    repo="${1:?Usage: sibling-repo.sh log <repo> [n]}"
    n="${2:-10}"
    repo_path=$(resolve_repo_path "$(resolve_siblings_dir)" "$repo")
    git -C "$repo_path" log --oneline "-$n"
    ;;
  branch)
    repo="${1:?Usage: sibling-repo.sh branch <repo>}"
    repo_path=$(resolve_repo_path "$(resolve_siblings_dir)" "$repo")
    git -C "$repo_path" branch -a
    ;;
  fetch)
    repo="${1:?Usage: sibling-repo.sh fetch <repo>}"
    repo_path=$(resolve_repo_path "$(resolve_siblings_dir)" "$repo")
    default_branch=$(get_default_branch "$repo_path")
    echo "Fetching $repo ($default_branch)..."
    git -C "$repo_path" fetch origin "$default_branch"
    echo "Done."
    ;;
  pull)
    repo="${1:?Usage: sibling-repo.sh pull <repo>}"
    repo_path=$(resolve_repo_path "$(resolve_siblings_dir)" "$repo")
    default_branch=$(get_default_branch "$repo_path")
    echo "Pulling $repo ($default_branch)..."
    git -C "$repo_path" pull origin "$default_branch"
    echo "Done."
    ;;
  ls)
    repo="${1:?Usage: sibling-repo.sh ls <repo> [path]}"
    subpath="${2:-.}"
    repo_path=$(resolve_repo_path "$(resolve_siblings_dir)" "$repo")
    ls -la "$repo_path/$subpath"
    ;;
  help | -h | --help)
    usage
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    usage
    exit 1
    ;;
esac
