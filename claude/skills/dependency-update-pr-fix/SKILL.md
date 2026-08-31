---
name: dependency-update-pr-fix
description: "Repair CI failures caused by Renovate, Dependabot, or similar dependency-update PRs by creating a separate fix PR from the latest origin default branch. Never modify the bot's PR branch."
---

# Dependency Update PR Fix

Use this skill when a dependency-update PR has failing CI and the failure should be fixed in the target repository. The intended outcome is a separate repair PR into the default branch. After that repair PR is merged, the dependency bot can rebase its original PR and rerun CI normally.

## Non-negotiable boundary

- Never checkout, edit, commit, push, force-push, rebase, merge, approve, or resolve review work on the dependency bot's PR branch.
- Create the repair branch from the latest `origin/<default-branch>`, not from the dependency PR head.
- Do not change the Renovate/Dependabot branch or its dependency versions as part of this workflow.
- Do not approve or merge the repair PR. Let the repository's normal reviewers and branch protections handle it; this avoids self-approval and preserves the bot PR's ability to rebase.
- If the current worktree is dirty or is itself the bot PR branch, preserve it and use a separate worktree for the repair. Do not reset or discard unrelated changes.

## Workflow

1. Identify the repository, the dependency PR, and its default branch. Use the existing GitHub authentication path and inspect the PR with `gh pr view <number> --json ...` and the repository with `gh repo view --json defaultBranchRef`. Confirm that the PR is a dependency update and record its URL, head branch, base branch, and failing checks.
2. Inspect the failure before editing. Read failed check details and logs with `gh pr checks <number>` and `gh run view <run-id> --log-failed`; inspect the PR diff with `gh pr diff <number>`. Distinguish a regression that belongs in the default branch from a problem in the dependency update itself or in CI infrastructure. If the latter cannot be fixed independently, stop and explain why.
3. Refresh the base and create an isolated repair branch. Run `git fetch origin <default-branch>` and base a new branch such as `feature/dependency-pr-<number>-ci-fix` directly on `origin/<default-branch>`. Prefer a separate `git worktree` when the current checkout has changes or could be the source PR branch. Verify the new branch and its base before making edits.
4. Implement the smallest maintainable fix on the repair branch. If reproducing the dependency interaction requires the bot diff, inspect it read-only or apply it temporarily in a disposable worktree; do not commit that dependency diff to the repair branch unless it is independently intended for the default branch.
5. Run focused tests first, then the relevant broader checks. Review `git diff`, `git status`, and the branch name. Before pushing, verify that the branch is not the original PR head and that its target is the default branch. If the default branch advanced, rebase only the repair branch onto the refreshed `origin/<default-branch>`.
6. Push only the repair branch and create a new PR targeting the default branch. The PR description should link the original dependency PR, summarize the failing CI signal and root cause, describe the fix, list verification, and explain that the separate branch intentionally leaves the bot PR rebaseable. Confirm the created PR's base and head with `gh pr view`.

## Stop conditions

Stop before mutating anything if the intended default branch cannot be determined, the source branch cannot be distinguished from the repair branch, the working tree cannot be preserved safely, or the fix would require changing the bot PR. Report the exact ambiguity or failure instead of guessing.
