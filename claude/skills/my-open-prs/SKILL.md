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

差分サイズ（小さい順）でリスト表示する。コピペしやすいようにテーブルではなくリスト形式で出力する：

```markdown
## オープンPR一覧（N件）

1. タイトル (+additions/-deletions)
URL

2. タイトル (+additions/-deletions)
URL

...
```

実際の出力例：

```
## オープンPR一覧（3件）

1. feat(eks): default EC2NodeClassのAMIをBottlerocketに変更 (+28/-3)
https://github.com/ajainc/am-glasgow-cdk/pull/1892

2. fix: Spot中断時のgraceful shutdown猶予を延長 (+91/-95)
https://github.com/ajainc/ssp-adserver/pull/8882

3. feat: Black/mypy を Ruff/ty に置換し pre-commit を導入 (+194/-68)
https://github.com/ajainc/glue-etl-job/pull/948
```

### プレゼンテーションルール

1. 差分サイズ昇順（total_changes）で表示
2. `--count N` 指定時は上位N件のみ
3. 各項目は「番号. タイトル (差分)」の行とURLの行で構成し、項目間は空行で区切る
4. デフォルトの除外条件（ドラフト、アーカイブ）は明示的に注記しない
5. `--exclude` で追加除外した場合は、何を除外したか簡潔に注記する
