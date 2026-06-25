# Codex Thread Handover Recovery Runbook

Use this runbook when a Codex implementation thread is stuck, has an unexpected approval/execution state, cannot be handed off cleanly, or keeps a Git branch occupied from an old worktree.

## 1. Tool Discovery

Use Codex thread-management tools when available:

- `read_thread`
- `list_threads`
- `handoff_thread`
- `get_handoff_status`
- `list_projects`
- `create_thread`
- `set_thread_archived`

If those tools are not visible in the current tool list, use tool discovery for the exact tool names before inventing a workaround. Do not use raw filesystem surgery on Codex state.

## 2. Thread Investigation

Start with the old thread:

```text
read_thread(threadId = "<old-thread-id>")
```

Record:

- `status`
- `cwd`
- `activeFlags`
- current project/worktree information
- recent user/assistant turns
- branch or PR references
- evidence that approval mode, execution mode, or tool availability is wrong

Use `list_threads` when needed to verify the old thread is still known, active, archived, or duplicated.

If the only problem is unclear instructions, prefer sending the old thread a clarifying message. If the problem is the runtime/approval state and no tool exposes a direct toggle, proceed with handoff or replacement.

## 3. Repository and Worktree Investigation

Use read-only Git commands first.

In the repository that owns the branch:

```bash
git worktree list
```

In the suspected old worktree:

```bash
git status --short --branch
git branch --show-current
git rev-parse HEAD
```

Interpretation:

- A worktree line showing `[feature/name]` means that worktree currently occupies the branch.
- `## HEAD (no branch)` or an empty `git branch --show-current` means detached HEAD and the branch is no longer occupied by that worktree.
- Any staged, unstaged, or untracked output in `git status --short --branch` must be treated as user-owned until proven otherwise.

## 4. Try Normal Handoff First

Prefer `handoff_thread` before manual branch release when:

- the old thread is readable;
- the target project is available;
- the desired branch is known;
- the main checkout/worktree does not have dirty or untracked files blocking checkout;
- no local work would be lost.

If handoff fails, inspect the reason with `get_handoff_status` when available. Common blockers:

- main checkout is on another branch;
- main checkout has dirty or untracked files;
- untracked `.codex/` or local config blocks checkout;
- target branch is already checked out by another worktree;
- old thread status does not permit handoff.

Do not fix a dirty checkout by deleting, stashing, or resetting files unless the user explicitly asks. Report the blocker and choose the safer path.

## 5. Safe Branch Release

Release a branch from an old Codex worktree only when the old worktree is clean.

Checklist before detaching:

```bash
git -C "<old-worktree-cwd>" status --short --branch
git -C "<old-worktree-cwd>" branch --show-current
git -C "<old-worktree-cwd>" rev-parse HEAD
```

If there are any changes after the `## ...` status line, stop. Ask the user whether to preserve, commit, or hand off those changes. Do not discard them.

If clean, detach the old worktree from the branch:

```bash
git -C "<old-worktree-cwd>" switch --detach HEAD
```

Verify:

```bash
git worktree list
git -C "<old-worktree-cwd>" status --short --branch
git -C "<old-worktree-cwd>" branch --show-current
```

Expected:

- `git worktree list` no longer shows the old worktree with `[target-branch]`.
- old worktree status says `## HEAD (no branch)`.
- `git branch --show-current` is empty.

Do not remove the old worktree unless the user explicitly asks.

## 6. Create the Replacement Thread

Find the project:

```text
list_projects
```

Create the new thread with:

```text
target.environment.type = "worktree"
startingState.type = "branch"
startingState.branchName = "<released-branch>"
```

The initial prompt must include:

- old thread ID;
- old cwd;
- branch name;
- why the thread was recreated;
- current work state;
- PR/Issue state;
- exact forbidden actions;
- first actions to take;
- information already verified in the old thread;
- information the new thread must re-check;
- whether the old worktree was detached and how that was verified.

### Replacement Thread Prompt Template

```text
You are taking over implementation work from an old Codex thread.

Old thread:
- threadId: <old-thread-id>
- cwd: <old-worktree-cwd>
- previous branch: <branch>

Reason for replacement:
- <approval/execution/handoff issue>
- Normal handoff was <attempted/not attempted> because <reason>.

Branch handover:
- The old worktree was checked with `git status --short --branch`, `git branch --show-current`, and `git rev-parse HEAD`.
- The old worktree was clean before release.
- The old worktree was detached with `git switch --detach HEAD`.
- Verification after release: <worktree list/status summary>.

Current work state:
- <summary of code, tests, PR, issue, deployment, or investigation state>

Known facts:
- <facts verified by the previous thread or coordinator>

Must re-check:
- <facts that may be stale or environment-dependent>

Forbidden:
- Do not rewrite history, amend, rebase, reset, or force-push unless explicitly instructed.
- Do not discard user changes.
- Do not modify unrelated files.
- <project-specific prohibitions>

First steps:
1. Inspect current branch status and recent commits.
2. Read project instructions.
3. Reconstruct the remaining task list.
4. Continue from the branch state, reporting blockers clearly.
```

## 7. User Report Template

Report in Japanese unless the user requested another language.

```text
原因:
- <what was wrong or most likely wrong>

直せなかった理由:
- <no exposed tool / thread state / approval mode limitation>

handoff 失敗理由:
- <handoff error or why it was skipped>

branch 開放確認:
- old cwd: <path>
- branch: <branch>
- before: <status summary>
- after: <detached HEAD / git worktree list summary>

新 thread:
- threadId or pendingWorktreeId: <id>
- starting branch: <branch>
- project: <project>

旧 thread:
- archive 推奨: <yes/no/defer>
- 理由: <why>
```

Archive the old thread only when the user asked for cleanup or when the replacement is confirmed usable and the old thread has no unique live work left. If unsure, leave it unarchived and report the recommendation.

## 8. Concrete Reference: EKS 1.33 prd Recovery

Original implementation thread:

- threadId: `019ef833-1f32-7062-afea-5da3501fbe52`
- cwd: `/Users/a14993/.codex/worktrees/a87e/am-glasgow-cdk`
- branch: `feature/prd-eks133-over-the-air-nodepool`
- project context: `ajainc/am-glasgow-cdk` EKS 1.33 prd construction management

Observed:

1. `read_thread` showed the old thread as `status: active` with `activeFlags: []`.
2. No exposed tool could directly toggle or restore the expected delegated approval mode.
3. `handoff_thread` failed during `checkout-local-branch`.
4. The failure indicated that local changes needed to be stashed or committed before handoff could continue.
5. The main checkout had untracked `.codex/` and a different branch state, so the coordinator did not delete or stash those files.
6. `git worktree list` showed the old worktree occupying `feature/prd-eks133-over-the-air-nodepool`.
7. The old worktree was checked for status, then detached with `git switch --detach HEAD`.
8. `git worktree list` and `git status --short --branch` confirmed `HEAD (no branch)` / detached state.
9. A new implementation thread was created with:
   - `target.environment.type = "worktree"`
   - `startingState.type = "branch"`
   - `startingState.branchName = "feature/prd-eks133-over-the-air-nodepool"`
10. Result:
   - pendingWorktreeId: `local:85dafe88-f2c6-4849-b7e3-07a9084512c4`

Key lesson:

- When normal handoff is blocked by dirty or untracked files that may belong to the user, do not clean them automatically. If the old worktree is clean and merely occupies the branch, detaching the old worktree is the narrow safe operation that releases the branch for a new worktree-backed thread.
