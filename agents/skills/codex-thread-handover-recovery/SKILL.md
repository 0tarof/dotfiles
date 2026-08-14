---
name: codex-thread-handover-recovery
description: Recover stuck Codex implementation threads and safely move their work to another thread. Use when a Codex thread has a broken approval/execution state, handoff fails, a worktree still holds the target branch, branch checkout is blocked by another thread or worktree, or the user wants to recreate a thread while preserving branch state and avoiding destructive Git operations.
---

# Codex Thread Handover Recovery

Recover a stuck Codex implementation thread by inspecting thread state, trying normal handoff first when appropriate, safely releasing a branch from an old worktree, and creating a replacement thread with enough context to continue.

Use Japanese with the user unless they ask otherwise.

## Required Reference

Read this reference before acting on any real handover or branch-release request:

```text
references/handover-runbook.md
```

The reference contains the investigation checklist, handoff decision rules, branch-release guardrails, `create_thread` prompt checklist, reporting template, and the concrete EKS 1.33 recovery example.

## Workflow

1. Discover the available thread tools. If `read_thread`, `list_threads`, `handoff_thread`, `get_handoff_status`, `list_projects`, `create_thread`, or archival tools are not visible, use tool discovery before proceeding.
2. Inspect the old thread with `read_thread`, then verify it is visible with `list_threads` when useful.
3. Inspect the repository/worktree state with read-only Git commands before making changes:
   - `git worktree list`
   - `git status --short --branch`
   - `git branch --show-current`
   - `git rev-parse HEAD`
4. Prefer normal `handoff_thread` first when the repository state is clean enough and handoff is supported. If it fails, inspect the handoff status/reason and report the blocker.
5. If the old worktree is only holding the branch and has no uncommitted changes, release it with `git switch --detach HEAD` from the old worktree, then verify with `git worktree list` and `git status --short --branch`.
6. Create a replacement thread with `create_thread`, `target.environment.type = "worktree"`, and `startingState.type = "branch"` using the released branch.
7. Give the new thread a full handover prompt: old thread ID, old cwd, branch, why it was recreated, current work status, PR/Issue state, forbidden actions, first steps, known facts, and facts that need re-checking.
8. Report what happened, including whether the old thread should be archived.

## Safety Rules

- Never delete, stash, reset, checkout over, or otherwise discard user changes just to make handoff work.
- Never run `git reset --hard`, `git checkout --`, `git clean`, force-push, rebase, squash, or amend unless the user explicitly asks.
- Do not detach an old worktree until you have checked that it has no uncommitted or untracked changes relevant to the work.
- If any old worktree has changes, stop and ask the user or the old thread how to preserve them.
- Treat untracked `.codex/`, local config, generated files, and dirty main checkouts as user-owned unless proven otherwise.
