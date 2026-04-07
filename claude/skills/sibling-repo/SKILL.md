---
name: sibling-repo
description: >-
  メインワークツリーの兄弟リポジトリを参照・操作するスキル。Worktreeで作業中でもメインワークツリーの並列にあるリポジトリのコード参照、
  CLAUDE.md確認、API/型定義の参照、Git状態確認、Issue作成、fetch/pullなどが可能。
  「しぶりん」「兄弟リポ」「隣のリポ」「sibling repo」「他のリポ」「別リポ」「〇〇リポ見て」「〇〇リポのコード」
  「〇〇リポのIssue作って」「〇〇リポをfetch」「〇〇リポのブランチ確認」「隣のプロジェクト」
  「関連リポ」などの依頼で起動。「しぶりん」はsibling repoの愛称。リポ名が文脈に出てきたら積極的に使う。
allowed-tools:
  - Bash(*sibling-repo.sh *)
  - Bash(gh issue:*)
  - Bash(gh repo:*)
  - Read
  - Glob
  - Grep
user-invocable: true
---

# Sibling Repo スキル

Worktreeやメインワークツリーから、同じ親ディレクトリにある兄弟リポジトリを参照・操作する。

**IMPORTANT: このスキルを使用する際は、特に指定が無い限り日本語でユーザーとコミュニケーションを取ってください。**

## ヘルパースクリプト

兄弟リポの操作は同梱の `scripts/sibling-repo.sh` を使う。
パス解決、一覧取得、Git操作がすべて1コマンドで完結するため、承認プロンプトも1回で済む。

スクリプトは `$HOME/.claude/skills/sibling-repo/scripts/sibling-repo.sh` にインストールされている。

### コマンド一覧

```bash
SCRIPT="$HOME/.claude/skills/sibling-repo/scripts/sibling-repo.sh"

# 兄弟リポ一覧（ブランチ・最新コミット付き）
$SCRIPT list

# 兄弟リポの絶対パスを取得
$SCRIPT path <repo>

# Git操作
$SCRIPT status <repo>
$SCRIPT log <repo> [件数]
$SCRIPT branch <repo>
$SCRIPT fetch <repo>
$SCRIPT pull <repo>

# ファイル一覧
$SCRIPT ls <repo> [サブパス]
```

### 使い方の例

```bash
# 一覧表示
$SCRIPT list

# rdstnnのログ最新5件
$SCRIPT log rdstnn 5

# clearusui.comのsrcディレクトリ確認
$SCRIPT ls clearusui.com src
```

## 起動パターン

### パターン1: リポ名指定で参照

ユーザーが「clearusui.com のsrc見て」のようにリポ名を直接指定した場合:

1. `$SCRIPT path <repo>` でパスを取得
2. 要求された操作を実行（Read/Glob/Grepでファイルを直接読むか、`$SCRIPT ls` でファイル一覧）

### パターン2: 一覧→選択フロー

ユーザーが「兄弟リポ一覧見せて」「他のリポ何がある？」のように聞いた場合:

1. `$SCRIPT list` で一覧表示
2. ユーザーの選択を待つ

### パターン3: 自動検出

タスクの文脈から関連しそうな兄弟リポが推測できる場合:

1. `$SCRIPT list` で兄弟リポを確認
2. 関連リポのCLAUDE.mdやREADMEをReadツールで確認して関連性を判断
3. 関連リポと判断理由をユーザーに提示

## できること

### 読み取り系

- **コード参照**: `$SCRIPT path <repo>` でパスを取得し、Read/Glob/Grepで直接ファイルを読む
- **設定確認**: CLAUDE.md、README、package.json、Cargo.tomlなどプロジェクト情報の参照
- **API/型定義**: TypeScriptの型定義、OpenAPIスキーマ、Protobufなど
- **Git状態**: `$SCRIPT status/log/branch <repo>` で確認

### 操作系

- **fetch/pull**: `$SCRIPT fetch/pull <repo>` でdefault branchの最新取得
- **Issue作成**: `gh issue create --repo "<owner>/<repo>" --title "タイトル" --body "本文"`
- **ブランチ確認**: `$SCRIPT branch <repo>` でリモートブランチの確認

### 操作時の注意

- **fetch/pullは確認してから**: 兄弟リポで作業中の変更を壊さないよう、実行前にユーザーに確認する
- **Issue作成は内容を確認**: タイトルと本文のドラフトをユーザーに見せてから作成する
- **破壊的操作は禁止**: 兄弟リポの `git reset --hard`、ブランチ削除、force push などは絶対にしない

## エラーハンドリング

- リポ名が見つからない場合: スクリプトが自動で兄弟リポ一覧を表示する
- `.git` がないディレクトリは自動的に除外される
- git操作が失敗した場合: エラー内容をユーザーに報告する
