---
name: auto-review-fix
description: PRの既存Greptileレビューを確認し、指摘への対応、セルフレビュー、スレッド返信、Resolveまで行うスキル。Greptileの有料再レビュー依頼は投げず、Devinレビューは見ない。「レビュー対応して」「レビュー待って」「PRのレビュー見て」「Greptileの指摘直して」「レビュー修正」などの依頼で起動。
allowed-tools:
  - Bash(gh repo view *)
  - Bash(gh pr view *)
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

# Greptileレビュー対応スキル

PRに付いた既存のGreptileレビューを確認し、技術的に妥当な指摘だけを修正するスキル。

**IMPORTANT: 日本語でユーザーとコミュニケーションを取ること。**

## 対象

| Bot | ユーザー名 | 対応 |
|-----|-----------|------|
| Greptile | `greptile-apps[bot]` / `greptile-apps` | 既存レビューを読み、妥当な指摘を修正し、スレッドに修正内容を返信してから自分でResolveする |
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

### 3. Greptileレビュー状態の確認

```bash
gh pr view <PR番号> --json state,comments,reviews
gh pr view <PR番号> --comments
```

確認するもの：
- PRの `state`（OPEN / CLOSED / MERGED）
- Greptileのレビューが付いているか
- GreptileのConfidence、Summary、Concerns、Issues、Recommendations、P2項目

確認しないもの：
- Devinのコメント
- Devin Reviewチェック
- Devinの未解決スレッド

### 4. 判定スクリプトの実行

```bash
${CLAUDE_SKILL_DIR}/check_bot_review_status.py <PR番号>
```

スクリプトはGreptileのみを判定し、JSON形式で結果を出力する。`all_complete` が `true` なら、現在のGreptileレビューはAPPROVEDまたはConfidence 5/5で、未解決Greptileスレッドが0件。

完了判定はスクリプトの出力に従うこと。スクリプトを実行せずに完了と判断してはならない。`gh` が使えない場合だけ、その制約を明示して手動確認に切り替える。

### 5. Greptileレビューが未着の場合

`@greptileai review` は投稿しない。

- PRがOPENの場合: 「Greptileレビューはまだ付いていないので待ちます」と報告し、必要なら5分後に再チェックする
- PRがOPENでない場合: 自動レビューが走らない可能性を報告する。手動レビュー依頼はこのスキルからは投げない

### 6. 未解決GreptileスレッドとSummaryの確認

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
}' -f owner='{owner}' -f repo='{repo}' -F pr=<PR番号>
```

GreptileのトップレベルSummaryコメントも必ず読む。未解決インラインコメントだけでなく、Summary内のConfidence、Concerns、Issues、Recommendations、P2項目をセルフレビュー観点として扱う。

### 7. 指摘への対応方針

Botの指摘を鵜呑みにしない。

各指摘に対して以下を判断する：
1. 指摘が技術的に正しいか
2. 修正することでコードが改善されるか
3. 過剰な修正や不要な変更を求めていないか

判断の結果：
- 同意する場合: コードを修正する
- 同意しない場合: 理由を整理し、必要ならスレッドに短く返信してResolveする
- 判断に迷う場合: ユーザーに確認する

### 8. 10巡程度のセルフレビュー

Greptileの結果を起点に、ローカルで批判的レビューを行う。

- Greptileのインラインコメント、Summary、P2項目、周辺コードのリスク、既存テスト、プロジェクトの実装スタイルからチェックリストを作る
- 10巡程度、バグ・回帰リスク・テスト不足・過剰修正が残っていないかを見る
- 各巡で具体的な問題が見つかったら修正し、関連するローカルチェックを再実行する
- このループ中にGreptileへ再レビュー依頼は投げない

### 9. 修正のコミット・プッシュ

修正がある場合：

```bash
git add path/to/file1 path/to/file2
git commit -m "fix: address Greptile review feedback"
git push
```

`git add .` や `git add -A` は使わない。コミットメッセージに生成AI由来のtrailerは付けない。

### 10. Greptileスレッドへ返信してResolve

修正・検証が終わったGreptileスレッドには、修正内容と確認内容を短く返信し、その後でResolveする。

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

Resolveしてよいのは、コード上の問題が修正済み、または指摘が不適切であることを十分に確認できた場合だけ。判断に迷う場合はResolveせずユーザーに確認する。

### 11. 状態報告

以下を簡潔に報告する：
- GreptileのConfidenceと未解決スレッド数
- 修正した内容
- スキップした指摘と理由
- 実行したチェック
- pushしたかどうか
- 返信・ResolveしたGreptileスレッド
- Devinは意図的に見ていないこと
- Greptileの有料再レビュー依頼は投げていないこと

## 自動ポーリング

このスキルが呼ばれたら、まず1回チェック・対応を行う。

まだGreptileレビューが付いていない、または未対応のGreptile指摘が残っていて、ユーザーが継続監視を望む場合は `CronCreate` で cron式 `*/5 * * * *`、プロンプト `/auto-review-fix`、`recurs: true` を設定して5分おきに再チェックする。

既にスケジュール済みかどうかは `CronList` で確認し、重複登録しないこと。

未対応のGreptile指摘がなくなったら、`CronDelete` でスケジュールを削除してループを終了する。

## 注意事項

1. `git add .` や `git add -A` は絶対に使用しない
2. Botの指摘でも技術的に正しいか判断してから対応する
3. 人間のレビューコメントはこのスキルの対象外
4. CIチェックが失敗している場合は、レビュー対応とは分けてユーザーに報告する
5. `@greptileai review` を投稿しない。GreptileのRe-trigger linkも使わない
6. Devinレビューは見ない、待たない、直さない、Resolveしない
7. Greptileスレッドは、修正内容をReplyしてから自分でResolveする
