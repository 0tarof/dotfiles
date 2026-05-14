---
alwaysApply: true
---

# Git Amend Rule

Do not use `git commit --amend` (or any equivalent history-rewriting command on an existing commit) without first asking the user for explicit permission.

Amending rewrites history and can silently discard previous work, so always confirm the intent before running it.
