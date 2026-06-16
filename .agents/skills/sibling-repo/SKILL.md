---
name: sibling-repo
description: Access and inspect sibling Git repositories located next to the main worktree of the current repository, even when Codex is running inside a linked worktree. Use when the user says "しぶりん", "兄弟リポ", "隣のリポ", "sibling repo", "other repo", asks to view code in another local repo, inspect a related repo's AGENTS.md/CLAUDE.md/README, check sibling repo Git status/log/branches, or fetch/pull a sibling repo.
---

# Sibling Repo

現在の Git リポジトリまたは linked worktree から、メインワークツリーと同じ親ディレクトリにある兄弟リポジトリを参照・操作する。

ユーザーとの会話は、特に指定がなければ日本語で行う。

## Core Idea

The key operation is resolving the main worktree path.

Use `git worktree list --porcelain` and read the first `worktree` entry as the main worktree. Then use `dirname <main-worktree>` as the sibling repository directory.

This makes the skill work even when Codex is running inside a linked worktree such as a Codex-managed worktree. The sibling repos should still be resolved relative to the repository's main checkout, not relative to the temporary worktree location.

## Bundled Script

Use the bundled helper script:

```bash
.agents/skills/sibling-repo/scripts/sibling-repo.sh <command> [args...]
```

When installed by Home Manager:

```bash
${CODEX_HOME:-$HOME/.codex}/skills/sibling-repo/scripts/sibling-repo.sh <command> [args...]
```

Prefer the helper for path resolution and Git status commands because it keeps the main-worktree logic consistent.

## Commands

```bash
SCRIPT=".agents/skills/sibling-repo/scripts/sibling-repo.sh"

# Debug path resolution
$SCRIPT main
$SCRIPT siblings-dir

# List sibling repos with current branch and latest commit
$SCRIPT list

# Resolve a sibling repo absolute path
$SCRIPT path <repo>

# Git inspection
$SCRIPT status <repo>
$SCRIPT log <repo> [count]
$SCRIPT branch <repo>

# Git network operations
$SCRIPT fetch <repo>
$SCRIPT pull <repo>

# List files in a sibling repo
$SCRIPT ls <repo> [subpath]
```

## Workflow

1. If the user asks for available sibling repos, run:
   ```bash
   <script> list
   ```
   Present the result directly and ask which repo to inspect if the target is unclear.

2. If the user names a repo, resolve it first:
   ```bash
   <script> path <repo>
   ```
   Then read files directly from that absolute path with normal file tools.

3. If the task depends on repository-specific instructions, check likely context files in this order when they exist:
   - `AGENTS.md`
   - `CLAUDE.md`
   - `README.md`
   - language/framework config files such as `package.json`, `flake.nix`, `go.mod`, `Cargo.toml`

4. If the user asks for Git state, use:
   ```bash
   <script> status <repo>
   <script> log <repo> 10
   <script> branch <repo>
   ```

5. If the user asks to fetch or pull a sibling repo, first check status and confirm the operation will not trample local work. Then run:
   ```bash
   <script> fetch <repo>
   <script> pull <repo>
   ```

6. If the user asks to create a GitHub issue in a sibling repo, draft the issue title/body first and ask for confirmation before running `gh issue create`.

## Safety

- Do not run destructive Git commands in sibling repos.
- Do not run `git reset --hard`, branch deletion, force push, or broad cleanup commands.
- Ask before `fetch` or `pull` when a sibling repo has local changes.
- Ask before creating GitHub issues or making remote writes.
- If repo name resolution fails, show the available sibling repo list from the helper.
