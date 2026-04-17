---
name: claude-worktrees
description: 現在のgitリポジトリのworktree一覧を、各worktreeのブランチ・関連PR・Claude Codeセッション情報・再開コマンドと一緒に表示するスキル。「ワークツリー一覧」「アクティブなClaude」「worktree list」「worktree表示」「再開コマンド」「claude worktree」「claudeの状態」「並行作業の状態」などの依頼で必ず起動すること。複数のworktreeでClaude Codeを並行で動かしている時に、どのworktreeで何が進んでいるかを俯瞰するのに使う。
allowed-tools:
  - Bash(*list_worktrees.sh)
user-invocable: true
---

# Claude Worktrees スキル

現在のgitリポジトリで **Claude Codeのセッションが存在する worktree** だけを、ブランチ・PR・セッション情報とセットで俯瞰表示するスキル。複数worktreeで並行作業する際の状況把握と、セッション再開コマンドの生成を支援する。

**IMPORTANT: 日本語でユーザーとコミュニケーションを取ること。**

## いつ使うか

- ユーザーが「今どのworktreeで何が動いてるか見たい」と聞いたとき
- Claude Codeセッションが複数worktreeにまたがっていて、どこから再開するか迷ったとき
- worktreeから作成したPRの状態もまとめて確認したいとき

## ワークフロー

### 1. データ取得

リポジトリのルートに移動していることを確認してからスクリプトを実行する。

```bash
${CLAUDE_SKILL_DIR}/scripts/list_worktrees.sh
```

スクリプトは以下の情報を含むJSON配列を返す：

- `path`: worktreeの絶対パス
- `branch`: ブランチ名（detached HEADの場合は `(detached)`）
- `worktree_name`: worktreeパスのbasename（`claude --worktree <name>` の引数に使う）
- `is_main`: メインworktree（リポジトリルート）かどうかの bool
- `prs`: `gh pr list --head <branch>` で見つかったPRの配列（title, number, url, state, isDraft）
- `claude.exists`: `~/.claude/projects/<encoded-path>/` が存在するか
- `claude.session_count`: そのディレクトリ内の `.jsonl` セッションファイル数
- `claude.latest_session_id`: 最新セッションのID（再開コマンドに使う）
- `claude.latest_mtime`: 最新セッションの更新時刻

### 2. プレゼンテーション

スクリプトはClaudeセッションがあるworktreeだけを返す。以下のフォーマットで、worktreeごとにまとめて表示する。見出し（`###`）で区切り、情報が密集しないように整形する。

```markdown
## アクティブなClaude Worktree（N件: リポジトリ名）

### <worktree-path> [branch: <branch>]

- PR: #<番号> <タイトル> (<state>) — <url>
    (PRがない場合は「なし」と表示)
- セッション: <count>件（最終更新: <latest_mtime>）
- 再開コマンド:
  ```
  claude --resume <session-id>
  ```
```

### プレゼンテーションルール

1. **worktreeの並び順**: `claude.latest_mtime` の降順（最近使ったものが上）で並べる。

2. **再開コマンドの出し分け**:
   - `is_main == true` のとき（メインワークツリー）:
     ```
     claude --resume <session-id>
     ```
   - `is_main == false` のとき（`claude -w` で作られた worktree）:
     ```
     claude --worktree <worktree_name> --resume <session-id>
     ```
   `--worktree` は `--resume` より前に置く。`cd` は付けない。`claude --worktree <name>` が必要なのは、メインリポジトリ以外の worktree で作られたセッションを再開する場合のみ。

3. **PR情報**: 各PRは1行で「#番号 タイトル (状態) — URL」形式。Draftは `(Draft)` を状態の後ろに付ける。複数ある場合は箇条書きで列挙。

4. **長いパスの扱い**: worktreeパスが長い場合でも省略せずそのまま表示する（参考情報として）。

### 3. サマリー（任意）

全体の末尾に一行でサマリーを付けると見通しが良い：

```
合計: Nアクティブworktree / オープンPRは K件
```

## 実装メモ

- Claude Codeは `~/.claude/projects/<encoded-path>/` 配下にセッションを保存する。パスのエンコーディングは「`/` と `.` を両方 `-` に置換」するだけ（例: `/Users/a/.cursor/bar` → `-Users-a--cursor-bar`）
- worktreeパースは `git worktree list --porcelain` が安定。ブランチは `branch refs/heads/<name>` 行から抽出、detached HEADは `detached` 行で判定する
- PR取得に失敗しても worktree 表示は継続する（スクリプト側で `|| echo "[]"` フォールバック済み）
