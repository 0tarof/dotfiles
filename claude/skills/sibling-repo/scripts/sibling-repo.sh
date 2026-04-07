#!/usr/bin/env bash
set -euo pipefail

# sibling-repo helper: メインワークツリーの兄弟リポジトリを操作するユーティリティ
# Usage:
#   sibling-repo.sh list                     - 兄弟リポ一覧（ブランチ・コミット付き）
#   sibling-repo.sh path <repo>              - 兄弟リポの絶対パスを出力
#   sibling-repo.sh status <repo>            - git status
#   sibling-repo.sh log <repo> [n]           - git log --oneline (デフォルト10件)
#   sibling-repo.sh branch <repo>            - git branch -a
#   sibling-repo.sh fetch <repo>             - default branchをfetch
#   sibling-repo.sh pull <repo>              - default branchをpull
#   sibling-repo.sh ls <repo> [path]         - ファイル一覧

resolve_siblings_dir() {
  local main_worktree
  main_worktree=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
  dirname "$main_worktree"
}

resolve_repo_path() {
  local siblings_dir="$1"
  local repo="$2"
  local repo_path="$siblings_dir/$repo"

  if [ ! -d "$repo_path/.git" ]; then
    echo "Error: '$repo' は兄弟リポジトリとして見つかりません" >&2
    echo "利用可能なリポジトリ:" >&2
    list_repos "$siblings_dir" >&2
    exit 1
  fi
  echo "$repo_path"
}

get_default_branch() {
  local repo_path="$1"
  git -C "$repo_path" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
}

list_repos() {
  local siblings_dir="$1"
  for dir in "$siblings_dir"/*/; do
    if [ -d "$dir/.git" ]; then
      local repo branch commit
      repo=$(basename "$dir")
      branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "detached")
      commit=$(git -C "$dir" log --oneline -1 2>/dev/null || echo "no commits")
      echo "$repo  [$branch]  $commit"
    fi
  done
}

SIBLINGS_DIR=$(resolve_siblings_dir)
CMD="${1:-list}"
shift || true

case "$CMD" in
  list)
    list_repos "$SIBLINGS_DIR"
    ;;
  path)
    repo="${1:?Usage: sibling-repo.sh path <repo>}"
    resolve_repo_path "$SIBLINGS_DIR" "$repo"
    ;;
  status)
    repo="${1:?Usage: sibling-repo.sh status <repo>}"
    repo_path=$(resolve_repo_path "$SIBLINGS_DIR" "$repo")
    git -C "$repo_path" status
    ;;
  log)
    repo="${1:?Usage: sibling-repo.sh log <repo> [n]}"
    n="${2:-10}"
    repo_path=$(resolve_repo_path "$SIBLINGS_DIR" "$repo")
    git -C "$repo_path" log --oneline "-$n"
    ;;
  branch)
    repo="${1:?Usage: sibling-repo.sh branch <repo>}"
    repo_path=$(resolve_repo_path "$SIBLINGS_DIR" "$repo")
    git -C "$repo_path" branch -a
    ;;
  fetch)
    repo="${1:?Usage: sibling-repo.sh fetch <repo>}"
    repo_path=$(resolve_repo_path "$SIBLINGS_DIR" "$repo")
    default_branch=$(get_default_branch "$repo_path")
    echo "Fetching $repo ($default_branch)..."
    git -C "$repo_path" fetch origin "$default_branch"
    echo "Done."
    ;;
  pull)
    repo="${1:?Usage: sibling-repo.sh pull <repo>}"
    repo_path=$(resolve_repo_path "$SIBLINGS_DIR" "$repo")
    default_branch=$(get_default_branch "$repo_path")
    echo "Pulling $repo ($default_branch)..."
    git -C "$repo_path" pull origin "$default_branch"
    echo "Done."
    ;;
  ls)
    repo="${1:?Usage: sibling-repo.sh ls <repo> [path]}"
    subpath="${2:-.}"
    repo_path=$(resolve_repo_path "$SIBLINGS_DIR" "$repo")
    ls -la "$repo_path/$subpath"
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    echo "Usage: sibling-repo.sh {list|path|status|log|branch|fetch|pull|ls} [args...]" >&2
    exit 1
    ;;
esac
