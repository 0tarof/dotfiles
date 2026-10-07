---
name: sibling-repo
description: Access and inspect sibling Git repositories located next to the main worktree of the current repository, even when running inside a linked worktree. Use when the user says "しぶりん", "兄弟リポ", "隣のリポ", "sibling repo", "他のリポ", "別リポ", "隣のプロジェクト", "関連リポ", asks to view code in another local repo (e.g. 「〇〇リポ見て」), inspect a related repo's AGENTS.md/CLAUDE.md/README, check sibling repo Git status/log/branches, fetch/pull a sibling repo, or create an issue in it. "しぶりん" is the nickname for sibling repo. Use it proactively when a sibling repo name comes up in context.
allowed-tools:
  - Bash(*sibling-repo.sh *)
  - Bash(gh issue *)
  - Bash(gh repo *)
  - Read
  - Glob
  - Grep
user-invocable: true
---

# Sibling Repo

現在の Git リポジトリまたは linked worktree から、メインワークツリーと同じ親ディレクトリにある兄弟リポジトリを参照・操作する。

ユーザーとの会話は、特に指定がなければ日本語で行う。

## Core Idea

The key operation is resolving the main worktree path.

Use `git worktree list --porcelain` and read the first `worktree` entry as the main worktree. Then use `dirname <main-worktree>` as the sibling repository directory.

This makes the skill work even inside a linked worktree such as a Codex- or Claude-managed worktree. The sibling repos are resolved relative to the repository's main checkout, not relative to the temporary worktree location.

## Bundled Script

Use the bundled helper script `scripts/sibling-repo.sh` in this skill directory:

- Claude Code: `${CLAUDE_SKILL_DIR}/scripts/sibling-repo.sh`
- Codex (installed by Home Manager): `$HOME/.agents/skills/sibling-repo/scripts/sibling-repo.sh`

Always invoke it by its expanded absolute path, e.g. `/Users/me/.agents/skills/sibling-repo/scripts/sibling-repo.sh list`. Do not put it in a shell variable or start the command with `$HOME`, `$SCRIPT`, or `~`: tirith blocks commands whose executable is an unexpanded variable. `<script>` below stands for that absolute path.

Prefer the helper for path resolution and Git status commands because it keeps the main-worktree logic consistent.

## Commands

```bash
# Debug path resolution
<script> main
<script> siblings-dir

# List sibling repos with current branch and latest commit
<script> list

# Resolve a sibling repo absolute path
<script> path <repo>

# Git inspection
<script> status <repo>
<script> log <repo> [count]
<script> branch <repo>

# Git network operations
<script> fetch <repo>
<script> pull <repo>

# List files in a sibling repo
<script> ls <repo> [subpath]
```

## Workflow

1. If the user asks for available sibling repos, run `<script> list`. Present the result directly and ask which repo to inspect if the target is unclear.

2. If the user names a repo, resolve it first with `<script> path <repo>`. Then read files directly from that absolute path with normal file tools.

3. If a related sibling repo can be inferred from the task, run `<script> list`, read the candidate's context files, and present the related repo with the reason.

4. If the task depends on repository-specific instructions, check likely context files in this order when they exist:
   - `AGENTS.md`
   - `CLAUDE.md`
   - `README.md`
   - language/framework config files such as `package.json`, `flake.nix`, `go.mod`, `Cargo.toml`

5. If the user asks for Git state, use `<script> status <repo>`, `<script> log <repo> 10`, and `<script> branch <repo>`.

6. If the user asks to fetch or pull a sibling repo, first check status and confirm the operation will not trample local work. Then run `<script> fetch <repo>` or `<script> pull <repo>`.

7. If the user asks to create a GitHub issue in a sibling repo, draft the issue title/body first and ask for confirmation before running `gh issue create --repo <owner>/<repo>`.

## Safety

- Do not run destructive Git commands in sibling repos.
- Do not run `git reset --hard`, branch deletion, force push, or broad cleanup commands.
- Ask before `fetch` or `pull` when a sibling repo has local changes.
- Ask before creating GitHub issues or making remote writes.
- If repo name resolution fails, show the available sibling repo list from the helper.
