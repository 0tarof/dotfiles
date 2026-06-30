---
name: auto-review-fix
description: Inspect and address existing Greptile PR review feedback without requesting paid re-reviews. Use when the user asks to handle Greptile feedback, check PR review status, fix Greptile comments, or continue an auto-review-fix loop after opening a PR.
---

# Auto Review Fix

PR に付いた既存の Greptile レビューを確認し、技術的に妥当な指摘だけを修正する。

ユーザーとの会話は、特に指定がなければ日本語で行う。

## Scope

| Bot | GitHub user | What to do |
| --- | --- | --- |
| Greptile | `greptile-apps[bot]` / `greptile-apps` | Read existing reviews, fix valid issues, reply to the review thread, then resolve it yourself after verification |
| Devin | `devin-ai-integration[bot]` | Ignore Devin review comments, checks, and status entirely |

Greptile re-review requests cost money. This skill must not post `@greptileai review` or use Greptile re-trigger links. If the user explicitly asks to request a new Greptile review, stop and confirm the cost before doing anything outside this workflow.

## Bundled Scripts

Use the scripts bundled in this skill directory:

- `check_bot_review_status.py`: machine-readable Greptile-only review status

When running them, resolve the path relative to this skill directory. If using the repository source directly, the path is:

```bash
.agents/skills/auto-review-fix/check_bot_review_status.py <PR_NUMBER>
```

When installed by Home Manager, the path is:

```bash
$HOME/.agents/skills/auto-review-fix/check_bot_review_status.py <PR_NUMBER>
```

## Codex App GitHub Auth

In Codex App, sandboxed commands may not be able to read macOS keyring-backed `gh` credentials. Run `gh` commands, and bundled scripts that invoke `gh`, with escalated / out-of-sandbox permissions so `gh` can use the system credential store.

Do not work around this by running `gh auth token` or copying the main GitHub token into Codex environment files.

## Workflow

1. Resolve the PR.
   - If the user gives a PR URL or number, use it.
   - Otherwise use the current branch:
     ```bash
     gh pr view --json number,title,url,state
     ```
   - If `gh` cannot resolve the PR, ask the user for the repository and PR number.

2. Read current Greptile state.
   ```bash
   gh pr view <PR_NUMBER> --json state,comments,reviews
   gh pr view <PR_NUMBER> --comments
   ```
   Check whether Greptile has reviewed and whether the PR is `OPEN`. Do not inspect Devin comments, checks, or review threads.

3. Run the status script before deciding completion.
   ```bash
   <skill-dir>/check_bot_review_status.py <PR_NUMBER>
   ```
   Treat the script as Greptile-only. `all_complete: true` means the current Greptile review is approved or Confidence 5/5, with zero unresolved Greptile review threads. Do not declare Greptile completion without running the script unless `gh` is unavailable and you clearly report that limitation.

4. If no Greptile review exists yet, do not request one.
   - If the PR is `OPEN`, report that no Greptile review is present yet and, if the user asked to keep watching, schedule a follow-up.
   - If the PR is not `OPEN`, report that automatic review may not run. Do not post `@greptileai review` from this skill.

5. Inspect unresolved actionable feedback.
   - Use GraphQL review threads when thread resolution state matters:
     ```bash
     gh api graphql -f query='
     query($owner: String!, $repo: String!, $pr: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $pr) {
           reviewThreads(first: 100) {
             nodes {
               id
               isResolved
               path
               line
               comments(first: 10) {
                 nodes {
                   author { login }
                   body
                   path
                   line
                 }
               }
             }
           }
         }
       }
     }' -f owner='<OWNER>' -f repo='<REPO>' -F pr=<PR_NUMBER>
     ```
   - Use `gh pr view <PR_NUMBER> --comments` for top-level Greptile summary comments, confidence notes, concerns, recommendations, and P2 items.

6. Judge each Greptile comment before editing.
   - Fix only comments that are technically correct and improve the code.
   - Skip comments that are stale, incorrect, overreaching, or inconsistent with project intent.
   - Ask the user when the tradeoff is real or the desired behavior is unclear.
   - Treat `greptile.summary_p2` from the status script as improvement candidates, not automatic requirements.

7. Run a self-critical review loop before finalizing fixes.
   - Build a checklist from Greptile inline comments, Greptile summary concerns, P2 items, nearby code risks, existing tests, and project style.
   - Do about 10 local review passes. In each pass, look for a concrete remaining bug, regression risk, missed test, or overfitted fix.
   - Fix issues found during those passes, then rerun relevant local checks.
   - Do not call Greptile again during this loop.

8. Implement fixes locally.
   - Keep edits scoped to the review feedback and the self-review issues it exposes.
   - Read the surrounding code and existing tests before changing behavior.
   - Use explicit `git add <path>` only; never use broad staging commands.
   - Commit with a normal project-style message. Do not add generated-by trailers.
   - Push after local checks pass when the PR branch needs the fixes.

9. Reply to and resolve Greptile threads yourself.
   - For each fixed Greptile review thread, reply with a short summary of the fix and the verification performed.
   - Use GraphQL `addPullRequestReviewThreadReply`, then `resolveReviewThread`.
   - Resolve only after verifying the code no longer has the issue. For skipped comments, resolve only when the rationale is clearly correct; otherwise ask the user.

   ```bash
   gh api graphql -f query='
   mutation($threadId: ID!, $body: String!) {
     addPullRequestReviewThreadReply(input: {
       pullRequestReviewThreadId: $threadId,
       body: $body
     }) {
       comment { url }
     }
   }' -f threadId='<THREAD_ID>' -f body='<FIX_SUMMARY>'

   gh api graphql -f query='
   mutation($threadId: ID!) {
     resolveReviewThread(input: {threadId: $threadId}) {
       thread { isResolved }
     }
   }' -f threadId='<THREAD_ID>'
   ```

10. Report status.
    Include Greptile confidence / unresolved count, what was fixed, what was skipped, what was pushed, which threads were replied to and resolved, and whether another human check is needed. Explicitly say that Devin was intentionally ignored and no paid Greptile re-review was requested.

## Polling and Follow-Up

Do one full check immediately.

If Greptile has not reviewed yet, unresolved Greptile feedback remains, or the user asked to keep watching, use Codex automations when available.

Use `automation_update` rather than Claude-style `CronCreate` commands:

- Prefer `kind=heartbeat` with `destination=thread` when the same Codex thread should wake up and continue the review loop.
- Use a 5-minute heartbeat schedule for normal review polling: `FREQ=MINUTELY;INTERVAL=5`.
- Use a self-contained prompt such as: `Continue auto-review-fix for <PR URL>. Check existing Greptile feedback, address actionable comments, reply to and resolve fixed threads, and stop the heartbeat when no actionable Greptile feedback remains. Do not request a Greptile re-review and ignore Devin.`
- Avoid duplicate schedules for the same PR. Inspect existing automations first when the tool supports it.
- Delete or pause the automation when no actionable Greptile feedback remains.

Use `kind=cron` only when the user explicitly wants a detached workspace job instead of continuing this thread.

If automation tools are not available, do not invent `CronCreate`-style commands. Report the current state and tell the user what needs to be checked next.

## Safety

- `git add .` and `git add -A` are forbidden.
- Do not use broad Git operations or force push unless the user explicitly asks.
- Do not post `@greptileai review`, use Greptile re-trigger links, or hide old review-request comments.
- Do not inspect, wait for, fix, or resolve Devin review output in this skill.
- Do not post review-thread replies or GraphQL mutations until the relevant code has been verified.
- Prefer `gh` for thread-aware state because flat comment views do not preserve review-thread resolution.
