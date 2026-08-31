---
name: resolve-conflict
description: Resolve conflicts between the current feature or PR branch and the latest origin default branch, run relevant tests, and push the resolved branch without rewriting history by default.
---

# Resolve Conflict

Use this skill when the current feature or PR branch conflicts with the latest default branch on `origin` and the user wants the branch repaired in one invocation. Carry the workflow through default-branch discovery, fetch, integration, semantic conflict resolution, verification, and push rather than stopping at the first conflict prompt.

Do not use this skill for Renovate, Dependabot, or other dependency-bot PR branches. Use `dependency-update-pr-fix` so the bot branch remains untouched and rebaseable.

## Safety rules

- Work only on the current feature or PR branch. Never switch to, edit, or push the default branch or another user's branch as part of the repair.
- Determine the repository's default branch from GitHub with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, then fetch it with `git fetch origin <default-branch>`. Do not use a stale local branch as the conflict source.
- The default integration is `git merge --no-edit origin/<default-branch>`. This preserves existing branch history and avoids force-push. Do not rebase or force-push unless the user explicitly requests that separate workflow.
- Require a clean worktree before starting. Do not silently stash, reset, clean, discard, or overwrite user changes. If the worktree is dirty, stop and report the paths.
- Resolve conflicts semantically. Do not apply a blanket `ours`, `theirs`, or mass replacement; preserve the feature behavior and the current default-branch behavior together.
- Push only the repaired current branch, and only after the merge is complete and tests pass. Never use `git push --force`.

## One-invocation workflow

1. Inspect `git branch --show-current` and `git status --porcelain`. Confirm the current branch is not the default branch. If a PR exists, inspect it with `gh pr view --json headRefName,baseRefName,state`; confirm that its head is the current branch and its base is the discovered default branch. If it is a dependency-bot branch, stop and route to `dependency-update-pr-fix`.
2. Discover the default branch, fetch it from `origin`, and record the fetched commit. If the default branch, remote branch, or current branch cannot be identified safely, stop before mutation.
3. Merge `origin/<default-branch>` into the current branch. If there are no conflicts, continue with verification; do not create unrelated edits.
4. For each unmerged path, inspect the conflict markers and nearby code with `git diff --cc` and `git diff --name-only --diff-filter=U`. Resolve each file deliberately, regenerate generated or lock files with the repository's documented command when appropriate, and verify that no conflict markers remain.
5. Stage only the explicitly resolved paths. Run `git diff --check` and relevant focused tests, followed by the repository's normal checks when practical. If tests fail because the resolution is uncertain or exposes an unrelated problem, stop before pushing and report the failure.
6. Complete the merge commit using the repository's normal hooks and message conventions. Recheck `git status --porcelain`, the current branch, and the diff against `origin/<default-branch>`.
7. Push the current branch with its existing upstream, or with `git push -u origin <current-branch>` when no upstream exists. Confirm the resulting PR still targets the default branch and that its head is the repaired current branch.

## Stop conditions

Stop before pushing if the branch is the default branch, the worktree was already dirty, the conflict involves a binary or an unresolved product decision, tests do not pass, the merge is not complete, or the PR head/base does not match the intended repair. Leave no hidden stash or destructive cleanup behind; report the exact state and next decision needed.
