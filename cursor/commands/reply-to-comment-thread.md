# PRレビューコメントスレッドへの返信コマンド

このコマンドは、GitHubのPRレビューコメント（コード行に対するコメント）のスレッドに返信するワークフローを自動化します。

**IMPORTANT: このコマンドを使用する際は、特に指定が無い限り日本語でユーザーとコミュニケーションを取ってください。**

## 前提知識

GitHubには2種類のコメントがあります：

| 種類 | 説明 | 返信方法 |
|------|------|----------|
| Issue/PRコメント | PRの一般的なコメント | `gh pr comment` で簡単に追加可能 |
| レビューコメント | コード行に対するコメント | REST API または GraphQL API が必要 |

## ワークフロー

### 1. コメント情報の取得

まず、返信したいコメントのIDを取得：

```bash
# PRのレビューコメント一覧を取得
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments
```

レスポンスから `id`（REST API用）または `node_id`（GraphQL用）を取得します。

### 2. 返信方法

#### 方法A: REST API（推奨）

`in_reply_to` パラメータを使用：

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  -X POST \
  -f body='返信内容' \
  -F in_reply_to={comment_id}
```

**例：**
```bash
gh api repos/ajainc/claude-plugins-ajainc/pulls/2/comments \
  -X POST \
  -f body='この指摘について確認しました。修正します。' \
  -F in_reply_to=2697106959
```

#### 方法B: GraphQL API

GraphQL APIを使用する場合（node_idが必要）：

```bash
gh api graphql -f query='
mutation AddPullRequestReviewThreadReply($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: $threadId
    body: $body
  }) {
    comment {
      id
      body
      url
    }
  }
}
' -f threadId='{node_id}' -f body='返信内容'
```

**注意**: GraphQL APIでは `node_id`（`PRRT_`で始まるID）が必要です。これはコメントの `node_id` ではなく、スレッドの `node_id` です。

### 3. スレッドIDの取得（GraphQL用）

コメントからスレッドIDを取得するには：

```bash
gh api graphql -f query='
query GetReviewThread($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 1) {
            nodes {
              body
              path
              line
            }
          }
        }
      }
    }
  }
}
' -f owner='{owner}' -f repo='{repo}' -F pr={pr_number}
```

### 4. スレッドをResolveする（GraphQL）

レビューコメントスレッドをResolveする場合は、GraphQL APIの `resolveReviewThread` mutationを使用します：

```bash
gh api graphql -f query='
mutation ResolveReviewThread($threadId: ID!) {
  resolveReviewThread(input: {
    threadId: $threadId
  }) {
    thread {
      id
      isResolved
    }
  }
}
' -f threadId='{thread_node_id}'
```

**例：**
```bash
gh api graphql -f query='
mutation ResolveReviewThread($threadId: ID!) {
  resolveReviewThread(input: {
    threadId: $threadId
  }) {
    thread {
      id
      isResolved
    }
  }
}
' -f threadId='PRRT_kwDOL1234567890abcdef'
```

#### Unresolveする場合

スレッドを再度Unresolveにする場合は、`unresolveReviewThread` mutationを使用します：

```bash
gh api graphql -f query='
mutation UnresolveReviewThread($threadId: ID!) {
  unresolveReviewThread(input: {
    threadId: $threadId
  }) {
    thread {
      id
      isResolved
    }
  }
}
' -f threadId='{thread_node_id}'
```

**注意**:
- スレッドをResolve/Unresolveするには、スレッドのnode ID（`PRRT_`で始まるID）が必要です
- コメントのnode IDではなく、スレッド自体のIDを使用してください
- スレッドIDは上記の「スレッドIDの取得」クエリで取得できます

## 実行例

### シナリオ: レビューコメントに返信

1. コメントIDを確認
```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments | jq '.[0] | {id, node_id, body}'
```

2. REST APIで返信
```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  -X POST \
  -f body='確認しました。この指摘は誤りです。公式ドキュメントによると...' \
  -F in_reply_to={comment_id}
```

## 重要な注意事項

1. **REST APIが簡単**：通常は `in_reply_to` パラメータを使うREST APIで十分
2. **GraphQLはスレッドID**：GraphQL APIではコメントIDではなくスレッドIDが必要
3. **認証**：`gh` コマンドは事前に認証済みである必要がある
4. **権限**：PRに対するコメント権限が必要
5. **日本語でコミュニケーション**：特に指定が無い限り、ユーザーとのやり取りは日本語で行う

## エラーハンドリング

| エラー | 原因 | 解決策 |
|--------|------|--------|
| 404 Not Found | リポジトリやPRが存在しない | owner/repo/pr番号を確認 |
| 422 Unprocessable | コメントIDが無効 | 正しいコメントIDを使用 |
| 401 Unauthorized | 認証エラー | `gh auth login` を実行 |

- コマンドが失敗した場合は、特に指定が無い限り日本語でエラーメッセージをユーザーに説明
- 次のステップに進む前に、問題を解決するための提案を提示
- 必要に応じて、ユーザーに追加の情報や確認を求める
