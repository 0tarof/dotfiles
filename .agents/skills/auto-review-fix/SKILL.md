---
name: auto-review-fix
description: Inspect and address PR bot reviews from Greptile and Devin. Use when the user asks to handle bot review feedback, wait for review completion, check PR review status, fix Greptile or Devin comments, request Greptile review, or continue a PR review loop after opening a pull request.
---

# Auto Review Fix

PR に付いた Greptile / Devin の bot レビューを確認し、技術的に妥当な指摘だけを修正し、必要に応じて再レビュー依頼まで進める。

ユーザーとの会話は、特に指定がなければ日本語で行う。

## Bot

| Bot | GitHub user | Re-review trigger | Complete when |
| --- | --- | --- | --- |
| Greptile | `greptile-apps[bot]` | PR comment: `@greptileai review` | APPROVED or Confidence 5/5, with zero unresolved Greptile review threads |
| Devin | `devin-ai-integration[bot]` | Usually triggered by push | "No Issues Found", or Devin Review check passed with zero unresolved Devin review threads |

## Bundled Scripts

Use the scripts bundled in this skill directory:

- `check_bot_review_status.py`: machine-readable Greptile / Devin completion status
- `minimize_old_review_comments.py`: hide old user-authored `@greptileai review` comments, keeping the newest one

When running them, resolve the path relative to this skill directory. If using the repository source directly, the paths are:

```bash
.agents/skills/auto-review-fix/check_bot_review_status.py <PR_NUMBER>
.agents/skills/auto-review-fix/minimize_old_review_comments.py <PR_NUMBER>
```

When installed by Home Manager, the paths are:

```bash
${CODEX_HOME:-$HOME/.codex}/skills/auto-review-fix/check_bot_review_status.py <PR_NUMBER>
${CODEX_HOME:-$HOME/.codex}/skills/auto-review-fix/minimize_old_review_comments.py <PR_NUMBER>
```

## Codex App GitHub Auth

In Codex App, sandboxed commands may not be able to read macOS keyring-backed
`gh` credentials. Run `gh` commands, and bundled scripts that invoke `gh`, with
escalated / out-of-sandbox permissions so `gh` can use the system credential
store.

Do not work around this by running `gh auth token` or copying the main GitHub
token into Codex environment files.

## Workflow

1. Resolve the PR.
   - If the user gives a PR URL or number, use it.
   - Otherwise use the current branch:
     ```bash
     gh pr view --json number,title,url,state
     ```
   - If `gh` cannot resolve the PR, ask the user for the repository and PR number.

2. Read current review state.
   ```bash
   gh pr view <PR_NUMBER> --json state,comments,reviews
   gh pr view <PR_NUMBER> --comments
   ```
   Check whether Greptile / Devin have reviewed, whether `@greptileai review` was already posted, and whether the PR is `OPEN`.

3. Run the status script before deciding completion.
   ```bash
   <skill-dir>/check_bot_review_status.py <PR_NUMBER>
   ```
   Treat `all_complete: true` as complete. Do not declare completion without running the script unless `gh` is unavailable and you clearly report that limitation.

4. Inspect unresolved actionable feedback.
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
   - Use `gh pr view <PR_NUMBER> --comments` for top-level summary comments and Greptile confidence notes.

5. Judge each bot comment before editing.
   - Fix only comments that are technically correct and improve the code.
   - Skip bot comments that are stale, incorrect, overreaching, or inconsistent with project intent.
   - Ask the user when the tradeoff is real or the desired behavior is unclear.
   - Treat `greptile.summary_p2` from the status script as improvement candidates, not automatic requirements.

6. Implement fixes locally.
   - Keep edits scoped to the review feedback.
   - Read the surrounding code and existing tests before changing behavior.
   - Use explicit `git add <path>` only; never use broad staging commands.
   - Commit with a normal project-style message. Do not add generated-by trailers.
   - Push after local checks pass if a push is needed to trigger Devin or re-run Greptile.

7. Request Greptile re-review only when justified.
   Greptile requests can cost money, so do not post casually. Post:
   ```bash
   gh pr comment <PR_NUMBER> --body "@greptileai review"
   ```
   only when all of these are true:
   - Greptile is not complete.
   - This loop made and pushed a relevant fix, or the latest push has not yet received a Greptile run.
   - The retry cap has not been reached.

   After posting a new request, hide old request comments:
   ```bash
   <skill-dir>/minimize_old_review_comments.py <PR_NUMBER>
   ```

8. Report status.
   Include Greptile confidence / unresolved count, Devin status, what was fixed, what was skipped, what was pushed, and whether another check is needed.

## First Review Request Rules

If no `@greptileai review` comment exists yet:

- If the PR is `OPEN`, do not manually request Greptile. Greptile / Devin may run automatically on open PRs. Report that you are waiting.
- If the PR is not `OPEN`, tell the user automatic review may not run. Ask before posting `@greptileai review` because it can cost money.

## Resolve Policy

Do not manually resolve bot review threads by default.

Greptile may be manually resolved only when both are true:

- The latest `@greptileai review` request has a `+1` reaction from `greptile-apps[bot]`, meaning the re-review ran.
- The relevant thread remains unresolved after the fix and re-review, and you have verified the code no longer has the issue.

Never manually resolve Devin threads. If Devin leaves a thread unresolved after a fix, re-check the implementation. If the requested change is impossible or harmful, explain the tradeoff and ask the user.

## Polling and Follow-Up

Do one full check immediately.

If the reviews are not complete and the user asked to keep watching, use Codex automations when available.

Use `automation_update` rather than Claude-style `CronCreate` commands:

- Prefer `kind=heartbeat` with `destination=thread` when the same Codex thread should wake up and continue the review loop.
- Use a 5-minute heartbeat schedule for normal review polling: `FREQ=MINUTELY;INTERVAL=5`.
- Use a self-contained prompt such as: `Continue auto-review-fix for <PR URL>. Check Greptile and Devin status, address actionable feedback if any, and stop the heartbeat when all bot reviews are complete.`
- Avoid duplicate schedules for the same PR. Inspect existing automations first when the tool supports it.
- Delete or pause the automation when all bot reviews are complete.

Use `kind=cron` only when the user explicitly wants a detached workspace job instead of continuing this thread.

If automation tools are not available, do not invent `CronCreate`-style commands. Report the current state and tell the user what needs to be checked next.

## Retry Limit

Aim for at most 10 Greptile review requests. Count existing `@greptileai review` comments in the PR history. If the cap is reached without completion, stop and ask the user how far to keep pushing.

## Safety

- `git add .` and `git add -A` are forbidden.
- Do not use broad Git operations or force push unless the user explicitly asks.
- Do not post review requests, comments, or GraphQL mutations unless the workflow says they are justified.
- Prefer `gh` for thread-aware state because flat comment views do not preserve review-thread resolution.
