---
name: auto-review-fix
description: PRのBotレビュー（Greptile、Devin）を監視し、レビュー指摘への対応・再レビュー依頼を自動化するスキル。「レビュー対応して」「レビュー待って」「PRのレビュー見て」「Greptileの指摘直して」「レビュー修正」などの依頼で起動。PRを作成した後のレビュー対応フローに使う。
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Edit
  - Write
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
| Greptile | `greptile-apps[bot]` | PRコメントで `@greptileai review` | Confidence 5/5 |
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
# PRのレビューコメントを確認
gh pr view <PR番号> --comments

# PRのレビューを確認（reviewとcommentは別）
gh api repos/{owner}/{repo}/pulls/<PR番号>/reviews
```

以下を確認する：
- Greptileのレビューが付いているか（`greptile-apps[bot]`）
- Devinのレビューが付いているか（`devin-ai-integration[bot]`）
- まだレビューが付いていない場合はユーザーに報告して終了（自動ポーリングで再度チェックされる）

### 3. レビュー状態の判定

#### Greptileの場合
- レビューコメントから Confidence レベルを確認する
- Confidence が 5/5 なら Greptile は完了
- 5/5 でなければ指摘内容を確認して対応する

#### Devinの場合

以下の**いずれか**を満たせば完了：
- 「Devin Review: No Issues Found」というコメントがある（初回レビュー時）
- `gh pr checks` で「Devin Review」のチェックが完了しており、かつ `devin-ai-integration[bot]` の未解決レビューコメントがない（2回目以降）

確認方法：
```bash
# checksでDevin Reviewの状態を確認
gh pr checks <PR番号>

# GraphQL APIでレビュースレッドの解決状態を確認
# REST APIではスレッド解決状態が取れないため、GraphQL APIを使う
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
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.comments.nodes[0].author.login == "devin-ai-integration[bot]") | select(.isResolved == false)'
```

未解決のDevinコメントが0件なら完了。指摘がある場合は内容を確認して対応する。

### 4. レビュー指摘への対応

**対応方針：指摘を鵜呑みにしない。**

各指摘に対して以下を判断する：
1. 指摘が技術的に正しいか
2. 修正することでコードが改善されるか
3. 過剰な修正や不要な変更を求めていないか

判断の結果：
- **同意する場合** → コードを修正する
- **同意しない場合** → スキップする（Botの指摘なのでコメント返信は不要）
- **判断に迷う場合** → ユーザーに確認する

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

Greptileが完了していない場合、pushした後に再レビューを依頼する：

```bash
gh pr comment <PR番号> --body "@greptileai review"
```

### 7. 状態報告

対応結果をユーザーに報告する：

```
## レビュー対応状況
- **Greptile**: Confidence 3/5 → 対応済み、再レビュー依頼済み（残りリトライ: 9/10）
- **Devin**: レビュー待ち

次回チェックで再確認します。
```

## リトライ管理

- Greptileの Confidence 5/5 を目指して最大 **10回** までリトライする
- 現在のリトライ回数は、PRのコメント履歴から `@greptileai review` の投稿回数で判断する
- 10回リトライしても5/5にならない場合は、ユーザーに報告して判断を仰ぐ

## 自動ポーリング

このスキルが呼ばれたら、まず1回チェック・対応を行い、まだ完了していない場合は `CronCreate` で cron式 `*/3 * * * *`、プロンプト `/auto-review-fix`、`recurs: true` を設定して3分おきに再チェックする。

既にスケジュール済みかどうかは `CronList` で確認し、重複登録しないこと。

ユーザーが「レビュー対応して」と言うだけで、全Botレビューが完了するまで自動で監視・対応し続ける。

- レビューがまだ付いていない場合 → 「まだレビューが付いていません。3分後に再チェックします」と報告
- レビューに対応して再依頼した場合 → 「対応済み、3分後に再チェックします」と報告
- 全Bot完了の場合 → 「全てのBotレビューが完了しました！」と報告し、`CronDelete` でスケジュールを削除してループを終了

## 注意事項

1. `git add .` や `git add -A` は絶対に使用しない
2. Botの指摘でも技術的に正しいか判断してから対応する
3. 人間のレビューコメントはこのスキルの対象外（CLAUDE.mdのPRレビュー対応ルールに従う）
4. CIチェックも確認し、失敗している場合はユーザーに報告する
