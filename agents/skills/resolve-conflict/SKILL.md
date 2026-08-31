---
name: resolve-conflict
description: Resolve conflicts between the current feature or PR branch and the latest origin default branch, run relevant tests, and push the resolved branch without rewriting history by default.
---

# Resolve Conflict

Use this skill when the current feature or PR branch conflicts with the latest default branch on `origin` and the user wants the branch repaired in one invocation. This is an agent workflow, not a shell script: continue through default-branch discovery, fetch, integration, semantic conflict resolution, verification, and push without stopping at the first conflict prompt or asking for confirmation during normal steps.

Do not use this skill for Renovate, Dependabot, or other dependency-bot PR branches. Use `dependency-update-pr-fix` so the bot branch remains untouched and rebaseable.

## Safety rules

- Work only on the current feature or PR branch. Determine the repository's default branch before validating the current branch, then never switch to, edit, or push the default branch or another user's branch as part of the repair.
- Determine the repository's default branch from GitHub with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, then fetch it with `git fetch origin <default-branch>`. Do not use a stale local branch as the conflict source.
- The default integration is `git merge --no-edit origin/<default-branch>`. This preserves existing branch history and avoids force-push. Do not rebase or force-push unless the user explicitly requests that separate workflow.
- Require a clean worktree before starting a new merge. An existing in-progress merge may be resumed only when its `MERGE_HEAD` is exactly the freshly fetched `origin/<default-branch>` commit; otherwise stop without aborting or discarding it. Do not silently stash, reset, clean, discard, or overwrite user changes.
- Resolve conflicts semantically. Do not apply a blanket `ours`, `theirs`, or mass replacement; preserve the feature behavior and the current default-branch behavior together.
- Push only the repaired current branch, and only after the merge is complete and tests pass. Never use `git push --force`.

## One-invocation workflow

1. Record the repository root and current branch with `git rev-parse --show-toplevel` and `git branch --show-current`. Discover the default branch with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`. If either branch cannot be identified safely, or the current branch is the default branch, stop before mutation.
2. Fetch the default branch with `git fetch origin <default-branch>` and record `git rev-parse origin/<default-branch>`. Inspect the PR with `gh pr view --json headRefName,baseRefName,state` when one exists; its head must be the current branch, its base must be the discovered default branch, and it must be open. A branch without a PR may still be repaired and pushed, but do not claim to have verified a PR.
3. Inspect `git status --porcelain=v1` and the repository state files. If a rebase, cherry-pick, or unrelated sequencer operation is in progress, stop. If `MERGE_HEAD` exists, confirm it exactly matches the freshly fetched `origin/<default-branch>` commit; resume that merge. If there is no in-progress merge, require an entirely clean worktree and merge `origin/<default-branch>` into the current branch with `git merge --no-edit origin/<default-branch>`.
4. For each unmerged path, inspect the conflict markers and nearby code with `git diff --cc -- <path>` and `git diff --name-only --diff-filter=U`. Resolve each file deliberately, regenerate generated or lock files with the repository's documented command when appropriate, and verify that no unmerged paths or conflict-marker lines remain. If the merge completed without conflicts, skip this step.
5. Stage only the paths reported as unmerged after deliberate resolution. Run `git diff --cached --check` and relevant focused tests, followed by the repository's normal checks when practical. If tests fail because the resolution is uncertain or exposes an unrelated problem, stop before pushing and report the failure.
6. Commit only when `MERGE_HEAD` still exists after all resolutions and checks, using `git commit --no-edit` with the repository's normal hooks and message conventions. If the merge was fast-forwarded, already up to date, or auto-committed without conflicts, do not create an extra commit. Recheck `git status --porcelain`, the current branch, and the diff against `origin/<default-branch>`.
7. Push the current branch with its existing upstream, or with `git push -u origin <current-branch>` when no upstream exists. If a PR exists, confirm afterward that it still targets the default branch and that its head is the repaired current branch.

## Stop conditions

Stop before pushing if the branch is the default branch, the worktree was dirty before a new merge, an existing merge is against a stale or unknown commit, a rebase/cherry-pick is in progress, the conflict involves a binary or an unresolved product decision, tests do not pass, the merge is not complete, or the PR head/base does not match the intended repair. Leave no hidden stash or destructive cleanup behind; report the exact state and next decision needed.
