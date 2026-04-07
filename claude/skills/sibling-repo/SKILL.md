---
name: sibling-repo
description: >-
  メインワークツリーの兄弟リポジトリを参照・操作するスキル。Worktreeで作業中でもメインワークツリーの並列にあるリポジトリのコード参照、
  CLAUDE.md確認、API/型定義の参照、Git状態確認、Issue作成、fetch/pullなどが可能。
  「しぶりん」「兄弟リポ」「隣のリポ」「sibling repo」「他のリポ」「別リポ」「〇〇リポ見て」「〇〇リポのコード」
  「〇〇リポのIssue作って」「〇〇リポをfetch」「〇〇リポのブランチ確認」「隣のプロジェクト」
  「関連リポ」などの依頼で起動。「しぶりん」はsibling repoの愛称。リポ名が文脈に出てきたら積極的に使う。
allowed-tools:
  - Bash(git worktree:*)
  - Bash(git -C:*)
  - Bash(git log:*)
  - Bash(git branch:*)
  - Bash(git fetch:*)
  - Bash(git pull:*)
  - Bash(git status:*)
  - Bash(git symbolic-ref:*)
  - Bash(ls:*)
  - Bash(dirname:*)
  - Bash(basename:*)
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

## メインワークツリーと兄弟リポの解決

Worktreeで作業していると、CWDがメインワークツリーとは全く別の場所（例: `~/.cursor/worktrees/`）にある。
兄弟リポを見つけるには、まずメインワークツリーのパスを特定し、その親ディレクトリを探す必要がある。

### パス解決の手順

```bash
# 1. メインワークツリーのパスを取得（worktree listの最初のエントリが常にメインワークツリー）
MAIN_WORKTREE=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')

# 2. 兄弟リポの親ディレクトリ
SIBLINGS_DIR=$(dirname "$MAIN_WORKTREE")

# 3. 兄弟リポ一覧（.gitがあるディレクトリのみ）
ls -d "$SIBLINGS_DIR"/*/ | while read dir; do
  [ -d "$dir/.git" ] && echo "$(basename "$dir")"
done
```

この手順は毎回実行すること。パスをハードコードしてはいけない。

## 起動パターン

### パターン1: リポ名指定で参照

ユーザーが「clearusui.com のsrc見て」のようにリポ名を直接指定した場合:

1. パス解決を実行
2. 指定されたリポ名が兄弟リポに存在するか確認
3. 要求された操作を実行

### パターン2: 一覧→選択フロー

ユーザーが「兄弟リポ一覧見せて」「他のリポ何がある？」のように聞いた場合:

1. パス解決を実行
2. 兄弟リポ一覧を表示（リポ名、最新コミット、現在のブランチを添える）
3. ユーザーの選択を待つ

### パターン3: 自動検出

タスクの文脈から関連しそうな兄弟リポが推測できる場合:

1. パス解決を実行
2. 兄弟リポのCLAUDE.mdやREADMEを確認して関連性を判断
3. 関連リポと判断理由をユーザーに提示

## できること

### 読み取り系

- **コード参照**: ファイル構造の確認、特定ファイルの内容読み取り、コード検索
- **設定確認**: CLAUDE.md、README、package.json、Cargo.tomlなどプロジェクト情報の参照
- **API/型定義**: TypeScriptの型定義、OpenAPIスキーマ、Protobufなど
- **Git状態**: ブランチ一覧、最新コミット、diff、log

```bash
# ファイル構造の確認
ls "$SIBLINGS_DIR/<repo-name>/src/"

# コード検索
grep -r "pattern" "$SIBLINGS_DIR/<repo-name>/src/"

# Git状態の確認
git -C "$SIBLINGS_DIR/<repo-name>" status
git -C "$SIBLINGS_DIR/<repo-name>" log --oneline -10
git -C "$SIBLINGS_DIR/<repo-name>" branch -a
```

### 操作系

- **fetch/pull**: default branchの最新取得
- **Issue作成**: `gh issue create` で兄弟リポにIssue作成
- **ブランチ確認**: リモートブランチの確認、差分の確認

```bash
# default branchを取得してfetch/pull
DEFAULT_BRANCH=$(git -C "$SIBLINGS_DIR/<repo-name>" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
git -C "$SIBLINGS_DIR/<repo-name>" fetch origin "$DEFAULT_BRANCH"
git -C "$SIBLINGS_DIR/<repo-name>" pull origin "$DEFAULT_BRANCH"

# Issue作成
gh issue create --repo "<owner>/<repo-name>" --title "タイトル" --body "本文"
```

### 操作時の注意

- **fetch/pullは確認してから**: 兄弟リポで作業中の変更を壊さないよう、実行前にユーザーに確認する
- **Issue作成は内容を確認**: タイトルと本文のドラフトをユーザーに見せてから作成する
- **破壊的操作は禁止**: 兄弟リポの `git reset --hard`、ブランチ削除、force push などは絶対にしない

## エラーハンドリング

- リポ名が見つからない場合: 兄弟リポ一覧を表示して正しいリポ名を選んでもらう
- `.git` がないディレクトリは除外する
- git操作が失敗した場合: エラー内容をユーザーに報告する
