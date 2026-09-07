---
name: auto-review-fix
description: PRの既存Greptileおよび人間のレビューを確認し、妥当な指摘への対応、セルフレビュー、必要な返信まで行うスキル。Greptileの有料再レビュー依頼は投げず、Devinレビューは見ない。「レビュー対応して」「レビュー待って」「PRのレビュー見て」「レビュー修正」などの依頼で起動。
allowed-tools:
  - Bash(gh repo view *)
  - Bash(gh pr view *)
  - Bash(gh pr comment *)
  - Bash(gh api graphql *)
  - Bash(*check_bot_review_status.py *)
  - Bash(*sync_pr_branch.py *)
  - Bash(git branch *)
  - Bash(git rev-parse *)
  - Bash(git fetch *)
  - Bash(git merge *)
  - Bash(git merge-base *)
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git add *)
  - Bash(git commit *)
  - Bash(git push *)
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - AskUserQuestion
  - CronCreate
  - CronList
  - CronDelete
user-invocable: true
---

# PRレビュー対応スキル

PRに付いた既存のGreptileレビューと人間のレビューを確認し、技術的に妥当な指摘だけを修正するスキル。

**IMPORTANT: 日本語でユーザーとコミュニケーションを取ること。**

## 対象

| Reviewer | ユーザー名 / 種別 | 対応 |
|-----|-----------|------|
| Greptile | `greptile-apps[bot]` / `greptile-apps` | 既存レビューを読み、妥当な指摘を修正し、スレッドに修正内容を返信してから自分でResolveする |
| 人間のレビュアー | 除外対象以外のGitHub `User` | レビュー本文、レビュー判定、コメント、スレッドを確認し、妥当な指摘を修正して確認内容を返信する。人間のスレッドは自動Resolveしない |
| Devin | `devin-ai-integration[bot]` | Devinのコメント、チェック、ステータスは一切見ない |

Greptileの再レビューリクエストは課金されるため、このスキルでは `@greptileai review` を投稿しない。GreptileのRe-trigger linkも使わない。ユーザーが明示的に新規レビュー依頼を求めた場合は、このワークフローから外れるため、必ず課金が発生することを伝えて確認してから扱う。

## ワークフロー

### 1. PR番号の特定

```bash
gh pr view --json number,title,url,state,headRefName,baseRefName,mergeable
```

PR番号がわからない場合はユーザーに確認する。

### 2. PRブランチを最新のデフォルトブランチに同期

Greptileのコメントを読む前に、同梱スクリプトでPRブランチを最新のデフォルトブランチと同期する。PRのbaseがデフォルトブランチでない場合は、デフォルトブランチを勝手にmergeしない。

```bash
${CLAUDE_SKILL_DIR}/sync_pr_branch.py prepare [--pr <PR番号>]
```

スクリプトがデフォルトブランチの特定、PRのhead/base/state検証、最新baseのfetch、merge開始までの機械的処理を行う。`SYNC_NOT_NEEDED`なら通常のレビュー確認へ進み、`MERGE_COMPLETED`なら同期に伴うテストを実行する。終了コード2の`CONFLICTS_NEED_RESOLUTION`は想定された引き継ぎなので失敗扱いにしない。

競合がある場合だけ、報告されたパスを意味を確認して個別に解消する。`ours`/`theirs`の一括適用は禁止する。バイナリ競合、仕様判断が必要な競合、古いまたは不明な`MERGE_HEAD`、dirtyなworktree、rebase/cherry-pick中の場合は停止する。ブランチ切り替え、stash、reset、clean、破棄、ユーザー変更の上書きはしない。

解消後に関連テストを実行し、次のスクリプトで検証、必要なstage、merge commit、pushを行う。

```bash
${CLAUDE_SKILL_DIR}/sync_pr_branch.py finish [--pr <PR番号>]
```

`finish`はconflict pathだけをstageし、`MERGE_HEAD`がある場合だけmerge commitを作成する。auto-merge commit、fast-forward、no-opの後に余計なcommitは作らない。同期処理について手動でstage、commit、force pushしてはならない。

### 3. Greptileと人間のレビュー状態の確認

```bash
gh pr view <PR番号> --json state,comments,reviews,reviewDecision
gh pr view <PR番号> --comments
```

確認するもの：
- PRの `state`（OPEN / CLOSED / MERGED）
- Greptileのレビューが付いているか
- GreptileのConfidence、Summary、Concerns、Issues、Recommendations、P2項目
- 人間の `reviewDecision`、レビュー本文、トップレベルコメント
- 人間による未解決スレッドとインラインコメント

確認しないもの：
- Devinのコメント
- Devin Reviewチェック
- Devinの未解決スレッド

コメント本文を読む前にauthorを分類する。Greptile（`greptile-apps[bot]` / `greptile-apps`）とGitHub `User`は対象にし、Devinのエントリは本文を読まずに破棄する。

### 4. 判定スクリプトの実行

```bash
${CLAUDE_SKILL_DIR}/check_bot_review_status.py <PR番号>
```

スクリプトはGreptileのみを判定し、JSON形式で結果を出力する。`all_complete` が `true` なら、現在のGreptileレビューはAPPROVEDまたはConfidence 5/5で、未解決Greptileスレッドが0件。この結果だけでスキル全体を完了と判断してはならず、人間のレビュー本文、判定、コメント、対応が必要なスレッドを別途確認する。

完了判定はスクリプトの出力に従うこと。スクリプトを実行せずに完了と判断してはならない。`gh` が使えない場合だけ、その制約を明示して手動確認に切り替える。

### 5. Greptileレビューが未着の場合

`@greptileai review` は投稿しない。

- PRがOPENの場合: 「Greptileレビューはまだ付いていないので待ちます」と報告する。ただし人間のレビュー指摘があれば先に対応し、必要なら5分後に再チェックする
- PRがOPENでない場合: 自動レビューが走らない可能性を報告する。手動レビュー依頼はこのスキルからは投げない

### 6. 未解決スレッドとSummaryの確認

スレッドの解決状態が必要な場合はGraphQLで確認する：

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
              author { login __typename }
              body
              path
              line
            }
          }
        }
      }
    }
  }
}' -f owner='{owner}' -f repo='{repo}' -F pr=<PR番号>
```

GreptileのトップレベルSummaryコメントと人間のトップレベルレビュー・コメントを必ず読む。未解決インラインコメントだけでなく、Summary内のConfidence、Concerns、Issues、Recommendations、P2項目をセルフレビュー観点として扱う。

スレッドは、authorがGreptileならGreptile、人間のGitHub `User`なら人間、Devinなら除外対象として扱う。除外対象の本文は読まない。

### 7. 指摘への対応方針

Greptileや人間の指摘を鵜呑みにしない。

各指摘に対して以下を判断する：
1. 指摘が技術的に正しいか
2. 修正することでコードが改善されるか
3. 過剰な修正や不要な変更を求めていないか

判断の結果：
- 同意する場合: コードを修正する
- 同意しない場合: 理由を整理し、必要ならスレッドに短く返信する。人間のスレッドはResolveしない
- 判断に迷う場合: ユーザーに確認する
- 人間の `CHANGES_REQUESTED` は、関連するレビュー本文とスレッドを確認するためのシグナルとして扱う。関係のない変更まで広げない

### 8. 10巡程度のセルフレビュー

Greptileと人間のレビュー結果を起点に、ローカルで批判的レビューを行う。

- Greptileと人間のインラインコメント、レビュー本文、Summary、P2項目、周辺コードのリスク、既存テスト、プロジェクトの実装スタイルからチェックリストを作る
- 10巡程度、バグ・回帰リスク・テスト不足・過剰修正が残っていないかを見る
- 各巡で具体的な問題が見つかったら修正し、関連するローカルチェックを再実行する
- このループ中にGreptileへ再レビュー依頼は投げない。人間のレビュアーへ新しいレビュー依頼を勝手に投げない

### 9. 修正のコミット・プッシュ

修正がある場合：

```bash
git add path/to/file1 path/to/file2
git commit -m "fix: address review feedback"
git push
```

`git add .` や `git add -A` は使わない。コミットメッセージに生成AI由来のtrailerは付けない。

### 10. レビュースレッドへ返信

修正・検証が終わったGreptileスレッドには、修正内容と確認内容を短く返信し、その後でResolveする。人間のレビューコメントには同じく修正内容と確認内容を返信するが、人間のスレッドは自動Resolveしない。スレッドのない人間のトップレベルレビューには、必要に応じて `gh pr comment <PR番号> --body '<返信内容>'` で返信する。

```bash
gh api graphql -f query='
mutation($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: $threadId,
    body: $body
  }) {
    comment { url }
  }
}' -f threadId='<THREAD_ID>' -f body='<修正内容と確認内容>'

gh api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { isResolved }
  }
}' -f threadId='<THREAD_ID>'
```

ResolveしてよいのはGreptileスレッドだけで、コード上の問題が修正済み、または指摘が不適切であることを十分に確認できた場合に限る。人間のスレッドは修正・返信後もレビュアーの確認に任せる。判断に迷う場合はResolveせずユーザーに確認する。

### 11. 状態報告

以下を簡潔に報告する：
- GreptileのConfidenceと未解決スレッド数
- 人間のレビュー判定、対応が必要なコメント、返信済みでレビュアー確認待ちのスレッド
- 修正した内容
- スキップした指摘と理由
- 実行したチェック
- pushしたかどうか
- 返信・ResolveしたGreptileスレッド
- 返信した人間のレビューコメントと、Resolveせず残したスレッド
- Devinは意図的に見ていないこと
- Greptileの有料再レビュー依頼は投げていないこと

## 自動ポーリング

このスキルが呼ばれたら、まず1回チェック・対応を行う。

まだGreptileレビューが付いていない、未対応のGreptile指摘または人間の指摘が残っていて、ユーザーが継続監視を望む場合は `CronCreate` で cron式 `*/5 * * * *`、プロンプト `/auto-review-fix`、`recurs: true` を設定して5分おきに再チェックする。

既にスケジュール済みかどうかは `CronList` で確認し、重複登録しないこと。

対応が必要なGreptile・人間の指摘がなくなったら、`CronDelete` でスケジュールを削除してループを終了する。修正して返信済みだが人間のレビュアー確認を待っているだけのスレッドは、対応が必要な指摘には数えない。

## 注意事項

1. `git add .` や `git add -A` は絶対に使用しない
2. Bot・人間を問わず、レビューの指摘が技術的に正しいか判断してから対応する
3. 人間のレビューコメントもこのスキルの対象。修正・検証後に返信するが、自動Resolveはしない
4. CIチェックが失敗している場合は、レビュー対応とは分けてユーザーに報告する
5. `@greptileai review` を投稿しない。GreptileのRe-trigger linkも使わない
6. Devinレビューは見ない、待たない、直さない、Resolveしない
7. Greptileスレッドは、修正内容をReplyしてから自分でResolveする
