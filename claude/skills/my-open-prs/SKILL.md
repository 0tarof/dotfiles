---
name: my-open-prs
description: 自分のオープンPRを差分サイズ順にリスト表示。デフォルトでドラフトPR・アーカイブ済みリポジトリを除外。「自分のPR」「open PR」「PRリスト」「PR一覧」「出してるPR」などの依頼で起動。
allowed-tools:
  - Bash(*fetch_open_prs.sh*)
  - Bash(gh pr view *)
  - Bash(gh pr list *)
  - Bash(gh search prs *)
  - Bash(gh api repos/*)
  - Bash(jq *)
  - Bash(grep *)
user-invocable: true
---

# My Open PRs スキル

自分が出しているオープンPRを差分サイズ順にリスト表示するスキル。

**IMPORTANT: 日本語でユーザーとコミュニケーションを取ること。**

## 引数

- `--exclude <説明>`: 追加の除外条件を自然言語で指定（例: `--exclude "bolas リポジトリ"`, `--exclude "Release PR"`）
- `--count N`: 表示件数を指定（デフォルト: 全件）
- `--org ORG`: 対象org（デフォルト: ajainc）
- `--include-drafts`: ドラフトPRも含める
- `--include-archived`: アーカイブ済みリポジトリのPRも含める

## ワークフロー

### 1. データ取得

```bash
${CLAUDE_SKILL_DIR}/scripts/fetch_open_prs.sh [--org ORG] [--include-drafts] [--include-archived]
```

スクリプトのオプションはユーザーの引数に応じて付与する。

### 2. 追加フィルタ

ユーザーが `--exclude` を指定した場合、スクリプト出力のJSONに対して追加のフィルタを適用する。
`--exclude` の内容は自然言語なので、PR のタイトル・リポジトリ名・その他の属性を見て判断する。

例:
- `--exclude "bolas"` → `repository.nameWithOwner` に `bolas` を含むPRを除外
- `--exclude "Release PR"` → `title` に `Release` を含むPRを除外
- `--exclude "100行以上"` → `total_changes` が100以上のPRを除外

### 3. プレゼンテーション

差分サイズ（小さい順）でテーブル表示する：

```markdown
## オープンPR一覧（N件）

| # | 差分 | リポジトリ | PR | タイトル |
|---|------|-----------|-----|---------|
| 1 | +28/-3 | am-glasgow-cdk | [#1892](URL) | feat(eks): ... |
| 2 | +22/-19 | bolas | [#5797](URL) | [Phase 2] ... |
...
```

### プレゼンテーションルール

1. 差分サイズ昇順（total_changes）で表示
2. `--count N` 指定時は上位N件のみ
3. リポジトリ名は `owner/name` の `name` 部分のみ表示
4. PR番号はURLへのリンクにする
5. デフォルトの除外条件（ドラフト、アーカイブ）は明示的に注記しない
6. `--exclude` で追加除外した場合は、何を除外したか簡潔に注記する
