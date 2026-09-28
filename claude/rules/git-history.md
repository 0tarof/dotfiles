# Git Commit History

- Unless the user explicitly instructs otherwise, preserve normal Git history by
  creating new commits on top of the current branch.
- Do not amend, squash, reset, or otherwise rewrite existing commits as a default
  workflow. `git commit --amend` is allowed only when the user has clearly and
  specifically asked for an amend.
- Never rewrite a branch other people build on, and never use a bare
  `git push --force`.

## Syncing a pull request branch with its base

When the current branch is a pull request branch that needs to take in changes
from its base branch, including to resolve a conflict, rebase rather than merge:

```
git fetch origin
git rebase origin/<base>
git push --force-with-lease
```

- Do not use `git merge origin/<base>` for this. A merge commit on a long-lived
  PR branch makes the GitHub diff and review history hard to follow.
- If the rebase conflicts across many commits, stop and report to the user
  instead of improvising a squash or a reset.
