---
name: auto-review-fix
description: PRのBotレビュー（Greptile、Devin）を監視し、レビュー指摘への対応・再レビュー依頼を自動化するスキル。「レビュー対応して」「レビュー待って」「PRのレビュー見て」「Greptileの指摘直して」「レビュー修正」などの依頼で起動。また「Greptileにレビュー依頼」「レビューリクエスト」「Greptileレビューして」などのレビュー依頼にも対応。PRを作成した後のレビュー依頼・対応フローに使う。
allowed-tools:
  - Bash(gh pr view *)
  - Bash(gh pr comment *)
  - Bash(gh pr checks *)
  - Bash(gh api graphql *)
  - Bash(*check_bot_review_status.py *)
  - Bash(*minimize_old_review_comments.py *)
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

# PR Botレビュー監視・対応スキル

PRに付いたBotレビュー（Greptile、Devin）を確認し、指摘への対応と再レビュー依頼を繰り返すスキル。

**IMPORTANT: 日本語でユーザーとコミュニケーションを取ること。**

## 対象Bot

| Bot | ユーザー名 | 再レビュー依頼方法 | 完了条件 |
|-----|-----------|-------------------|---------|
| Greptile | `greptile-apps[bot]` | PRコメントで `@greptileai review` | APPROVED(+1) または Confidence 5/5、かつ未解決インラインコメント0件 |
| Devin | `devin-ai-integration[bot]` | pushすれば自動で再レビュー | 下記参照 |

## ワークフロー

### 1. PR番号の特定

```bash
# 現在のブランチのPRを取得
gh pr view --json number,title,url
```

PR番号がわからない場合はユーザーに確認する。

### 2. レビューコメントの確認

```bash
# PRの状態とレビューコメントを確認
gh pr view <PR番号> --json state,comments,reviews

# 必要に応じて表示用に取得
gh pr view <PR番号> --comments
```

以下を確認する：
- PRの `state`（OPEN / CLOSED / MERGED）
- Greptileのレビューが付いているか（`greptile-apps[bot]`）
- Devinのレビューが付いているか（`devin-ai-integration[bot]`）
- 過去に `@greptileai review` コメントが投稿されているか

#### 初回リクエストの扱い（重要：課金抑制）

**Greptileは1リクエストごとに課金が発生するため、むやみにリクエストを送らない。**

`@greptileai review` コメントがまだ存在しない（＝初回チェック）の場合：

- **PRが OPEN の場合** → 何もしない。GreptileとDevinはOpenなPRに自動レビューが走るため、こちらからコメントしない。そのまま次のチェックを待つ。
- **PRが OPEN でない場合（CLOSED / MERGED 等）** → 自動レビューが効かない。以下を実施：
  1. ユーザーに「PRが OPEN ではないため Greptile / Devin の自動レビューは走りません」と伝える
  2. `AskUserQuestion` で「Greptileに手動でレビューリクエストしますか？（課金が発生します）」を確認
  3. ユーザーがYesの場合のみ `gh pr comment <PR番号> --body "@greptileai review"` を実行
  4. ユーザーがNoの場合はスキップしてループも終了する

`@greptileai review` コメントが既に存在する場合は、後述の「6. Greptileへの再レビュー依頼」のフローに従う。

### 3. レビュー状態の判定

**まず判定スクリプトを実行して、機械的にステータスを確認する：**

```bash
${CLAUDE_SKILL_DIR}/check_bot_review_status.py <PR番号>
```

スクリプトはJSON形式で結果を出力する。`all_complete` が `true` なら全Bot完了。
**完了判定はスクリプトの出力に従うこと。スクリプトを実行せずに完了と判断してはならない。**

#### Greptileの場合
- スクリプト出力の `greptile.complete` が `true` なら完了
- 完了条件（以下の**いずれか**、かつ未解決インラインコメント0件）：
  - レビューが **APPROVED（+1）** である
  - Confidence が **5/5** である
- Confidence が 5/5 でもインラインコメントが未解決なら、コメント内容を確認して対応する
- Confidence が 5/5 でなくAPPROVEDでもなければ指摘内容を確認して対応する
- **Summary内のP2対応**: `greptile.summary_p2` にアイテムがある場合、P2もConfidenceに影響しうる改善事項として対応する（P2は直接Confidenceに反映されないことが多いが、コード品質向上のため修正する）
- **Summaryコメントのヒント確認**: 未解決インラインコメントが0件なのに Confidence が 5/5 にならない・APPROVEDにならない場合、Summaryのコメント本文に減点理由のヒントが書かれている可能性がある。`gh pr view <PR番号> --comments` でGreptileのSummaryコメント本文を読み、`Confidence`、`Concerns`、`Issues`、`Recommendations` などのセクションに記載がないか確認する。記載があれば、それをインラインコメントと同じ判断基準で対応する。

#### Devinの場合
- スクリプト出力の `devin.complete` が `true` なら完了
- 完了条件（以下の**いずれか**）：
  - 「Devin Review: No Issues Found」というコメントがある（初回レビュー時）
  - `gh pr checks` で「Devin Review」のチェックが完了しており、かつ `devin-ai-integration[bot]` の未解決レビューコメントがない（2回目以降）

#### 手動確認（デバッグ用）

スクリプトが使えない場合のフォールバック：

```bash
# checksでDevin Reviewの状態を確認
gh pr checks <PR番号>

# GraphQL APIでレビュースレッドの解決状態を確認
gh api graphql -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 1) {
            nodes {
              author { login }
              body
            }
          }
        }
      }
    }
  }
}' -f owner='{owner}' -f repo='{repo}' -F pr=<PR番号> \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
```

### 4. レビュー指摘への対応

**対応方針：指摘を鵜呑みにしない。**

#### インラインコメント（未解決スレッド）
各指摘に対して以下を判断する：
1. 指摘が技術的に正しいか
2. 修正することでコードが改善されるか
3. 過剰な修正や不要な変更を求めていないか

判断の結果：
- **同意する場合** → コードを修正する
- **同意しない場合** → スキップする（Botの指摘なのでコメント返信は不要）
- **判断に迷う場合** → ユーザーに確認する

#### Summary内のP2アイテム
`check_bot_review_status.py` の出力に `summary_p2` がある場合、SummaryにP2の指摘が含まれている。
P2はConfidenceスコアに直接影響しないことが多いが、コード品質向上のため対応する：
- P2の内容を確認し、技術的に妥当なら修正する
- インラインコメントと同じ判断基準で対応する（鵜呑みにしない）
- P2対応はインラインコメント対応と一緒にまとめてコミットする

#### インラインコメントのResolve方針

**基本的にBotが自動でResolveするので、こちらから勝手にResolveしない。** 例外を以下に整理する。

##### Greptileのインラインコメント
- 修正をpushすれば、Greptileが直った箇所のスレッドを自動でResolveしてくれることが多い
- ただし、**Greptileが再レビュー後も該当スレッドを自動Resolveしない**ことがある
- 以下の **両方** を満たす場合に限り、こちら側で手動Resolveしてよい：
  1. **直近の `@greptileai review` コメントに Greptile（`greptile-apps[bot]`）が `+1` リアクションを付けている**（＝再レビュー実行＆完了済みのサイン）
  2. それでも該当インラインスレッドが Resolve されないまま残っている（複数回のレビューループでResolveされないことを観察した上で判断）
- それ以外（初回レビュー直後、まだ +1 リアクションが付いていないなど）は手動Resolveしないこと

`+1` リアクションの確認方法：

```bash
# 最新の "@greptileai review" コメントへの greptile-apps[bot] の +1 リアクションを確認
gh api graphql -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      comments(last: 50) {
        nodes {
          body
          createdAt
          reactions(first: 20, content: THUMBS_UP) {
            nodes { user { login } }
          }
        }
      }
    }
  }
}' -f owner='{owner}' -f repo='{repo}' -F pr=<PR番号>
```

スレッドのResolveは GraphQL の `resolveReviewThread` mutation を使う：

```bash
gh api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { isResolved }
  }
}' -f threadId='<thread node id>'
```

##### Devinのインラインコメント
- Devinは修正をpushすれば、修正された箇所のインラインコメント等を **自動でResolveする** のが基本
- **こちら側からは絶対に勝手にResolveしない**
- Devinが自動Resolveしないまま残っているコメントは、修正が不十分・整合性が取れていない可能性が高い：
  - まずは指摘を再度精査し、できるだけ正しい実装で直すことを試みる
  - 単なる見落としや表面的な対応で済ませない
- ただし、その指摘どおりに直すには無理がある（前提条件が合わない、設計上不可能、副作用が大きすぎる等）と判断できる場合は：
  - **不用意なワークアラウンドや黙殺はしない**
  - ユーザーに状況を整理して伝え、判断を仰ぐ（`AskUserQuestion` 等）

### 5. 修正のコミット・プッシュ

修正がある場合：

```bash
# 変更をステージング（明示的なパスで）
git add path/to/file1 path/to/file2

# コミット
git commit -m "$(cat <<'EOF'
fix: address bot review feedback

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"

# プッシュ（Devinの再レビューが自動トリガーされる）
git push
```

### 6. Greptileへの再レビュー依頼

**再レビュー依頼も1回ごとに課金が発生するため、不要に投げない。**

以下の **すべて** を満たす場合のみ、再レビューを依頼する：
- Greptileが完了していない（Confidence 5/5 でも APPROVED でもない、または未解決インラインコメントが残る）
- 今回のループで実際に修正をコミット＆pushした、または前回のpushに対する再レビューがまだ走っていない
- リトライ上限（後述）に達していない

修正なしで状態だけが変わらない場合に再レビューを連投しないこと。

```bash
gh pr comment <PR番号> --body "@greptileai review"
```

古い `@greptileai review` コメントを非表示にする：

```bash
${CLAUDE_SKILL_DIR}/minimize_old_review_comments.py <PR番号>
```

### 7. 状態報告

対応結果をユーザーに報告する：

```
## レビュー対応状況
- **Greptile**: Confidence 3/5、未解決コメント2件 → 対応済み、再レビュー依頼済み（残りリトライ: 9/10）
- **Devin**: レビュー待ち

次回チェックで再確認します。
```

## リトライ管理

- Greptileの Confidence 5/5 を目指して最大 **10回** までリトライする
- 現在のリトライ回数は、PRのコメント履歴から `@greptileai review` の投稿回数で判断する
- 10回リトライしても5/5にならない場合は、ユーザーに報告して判断を仰ぐ

## 自動ポーリング

このスキルが呼ばれたら、まず1回チェック・対応を行い、まだ完了していない場合は `CronCreate` で cron式 `*/5 * * * *`、プロンプト `/auto-review-fix`、`recurs: true` を設定して5分おきに再チェックする。

既にスケジュール済みかどうかは `CronList` で確認し、重複登録しないこと。

ユーザーが「レビュー対応して」と言うだけで、全Botレビューが完了するまで自動で監視・対応し続ける。

- **PRが OPEN かつレビューがまだ付いていない場合** → 自動レビューを待つだけ（Greptileに手動コメントしない）。「PRがOpenなので自動レビューを待ちます。5分後に再チェックします」と報告
- **PRが OPEN でなくレビューも未着手の場合** → `AskUserQuestion` でGreptileへのリクエスト可否を確認。Yesならコメント投稿後に「レビューを依頼しました。5分後に再チェックします」と報告。Noなら「レビュー依頼を見送りました」と報告し、`CronDelete` でループを終了
- レビューに対応して再依頼した場合 → 「対応済み、5分後に再チェックします」と報告
- 全Bot完了の場合 → 「全てのBotレビューが完了しました！」と報告し、`CronDelete` でスケジュールを削除してループを終了

## 注意事項

1. `git add .` や `git add -A` は絶対に使用しない
2. Botの指摘でも技術的に正しいか判断してから対応する
3. 人間のレビューコメントはこのスキルの対象外（CLAUDE.mdのPRレビュー対応ルールに従う）
4. CIチェックも確認し、失敗している場合はユーザーに報告する
5. Greptileがコメントに記載する再トリガーURL（Re-trigger linkなど）は認証が必要なため使用できない。再レビュー依頼は必ず `@greptileai review` コメントで行うこと
6. **Greptileは1リクエストごとに課金される。** 初回はPRが OPEN なら自動レビュー任せにし、こちらからコメントしない。再レビュー依頼も「修正をpushした」または「前回pushに対する再レビューがまだ走っていない」場合に限る
7. **インラインコメントを勝手にResolveしない。** Greptileは「直近の `@greptileai review` への +1 リアクション後も未Resolveのまま」の場合に限り手動Resolve可。Devinは常に手動Resolveしない（自動Resolveされない場合は実装を見直し、無理ならユーザーに判断を仰ぐ）
