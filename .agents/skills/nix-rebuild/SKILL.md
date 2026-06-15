---
name: nix-rebuild
description: dotfiles リポジトリの Nix 設定変更をコミットして `nix-rebuild` を走らせ、失敗時はエラーを解析して修正し、最終的に成功したら `git push` まで自動でやり切るスキル。「nix-rebuild して」「設定反映して」「rebuildして」「nix変更したからrebuild」「dotfilesに反映」「Nix適用」などの依頼で起動する。Nix flake はコミット済みの状態しか見ないので「変更したけど反映されない」問題を含めて、コミット忘れによる事故を防ぐためにも積極的に使う。
---

# nix-rebuild スキル

このリポジトリ（`~/projects/github.com/0tarof/dotfiles`）の Nix / Home Manager 設定変更を、
コミット → `nix-rebuild` → エラー時修正 → push まで一貫で実行する。

## なぜこのスキルがあるか

Nix flake は **未コミットの変更をビルド対象に含めない**。普通に `nix-rebuild` を叩いても、
`git add` してないファイルは丸ごと無視される。これに気づかず「変わってない…」と悩むのはよくある罠。
だから「コミット → rebuild」をワンセットで扱う必要がある。

加えて、このリポジトリでは：
- `git add -A` は settings.json で deny されてる（巻き込み事故防止）
- pre-commit hook で `--no-verify` も禁止
- `nix-rebuild` は `~/bin/nix-rebuild` のラッパー（flake.nix を環境変数経由で参照）

これらを毎回意識せず安全に回すために、このスキルが存在する。

## 実行フロー

```
1. git status で変更を確認
   ├─ 変更なし → 「変更ないけど rebuild する？」とユーザーに確認 → rebuild のみ
   └─ 変更あり → 次へ

2. 変更内容を把握する
   - git diff / git diff --cached を読んで、何が変わったか理解する
   - 関連ない変更が混ざっていれば、ユーザーに分割するか聞く
     （例: 設定ファイル変更と無関係なドキュメント修正が同時にある等）

3. ファイルを明示的に git add（git add -A は使わない）
   - 個別パスで add する: `git add path/to/file1 path/to/file2`
   - シークレット候補（.env、credentials.json、id_rsa等）は add しない。混入してたら警告

4. コミットメッセージを生成してコミット
   - 内容から自然なメッセージを構築（feat/fix/chore/docs などのプレフィックスを使う）
   - 既存コミットの style を `git log -5 --oneline` で確認して合わせる
   - HEREDOC でメッセージを渡す（複数行・引用符を安全に扱うため）

5. nix-rebuild を実行
   - `nix-rebuild` をフォアグラウンドで実行（sudo パスワード要求の可能性あり）
   - 出力は最後 30〜50 行を見ればだいたい結果がわかる

6. 結果分岐
   ├─ 成功 → `git push` で origin に反映 → 完了報告
   └─ 失敗 → 7. へ

7. エラー解析と修正
   - エラーメッセージを読んで原因を特定
   - 直せそうなら修正してステップ 3 から再実行
   - 直せない／判断が要るなら、原因とエラー出力をユーザーに見せて指示を仰ぐ
   - 修正コミットは新コミット（--amend しない、push 済みでなくても揃える）
```

## 詳細ガイド

### コミット前のチェック

`git status` の出力を見る前後で、以下を確認する：

- **意図しないファイルが含まれてないか**
  - 一時ファイル、ビルド成果物、シークレット系
- **今回の変更スコープに合った範囲か**
  - 「Docker completion 追加」と言われたのに無関係な home.nix の編集が混ざっていたら一度立ち止まる
- **`overlay/` 配下の変更**
  - `overlay/` は gitignore 対象（会社固有設定）。ここの変更は親リポにコミットされない。
    `overlay/` 自体が独立した git リポジトリ（clone されている）の場合、そのリポジトリ内でコミットする。

### コミットメッセージのスタイル

このリポジトリの既存スタイルを踏襲：

```
<type>: <短い要約>

<必要なら詳細説明>

```

`type` は `feat` / `fix` / `chore` / `docs` / `refactor` などを使う。
本文に `-n` や `--no-verify` を含めると pre-commit hook（`block-git-no-verify.sh`）が
反応する場合があるので、必要ならフレーズを言い換える（例: `the no-verify flag`）。

### nix-rebuild の起動

```bash
nix-rebuild
```

これは `~/bin/nix-rebuild` のラッパーで、内部的に：

- macOS: `sudo darwin-rebuild switch --flake "$DOTFILES_DIR#$NIX_HOSTNAME" --impure`
- Linux: `home-manager switch --flake "$DOTFILES_DIR#$NIX_USERNAME@$NIX_HOSTNAME" --impure`

を呼ぶ。macOS の場合 sudo が走るのでパスワード入力の可能性あり。

完了後に `mise install` も自動実行される。

### よくあるエラーと対処

| エラーパターン | 原因 | 対処 |
|---|---|---|
| `error: getting status of '/nix/store/...-source/...': No such file or directory` | コミット忘れ | ファイルを `git add` してコミット |
| `error: undefined variable 'foo'` | typo / import 漏れ | 該当 `.nix` ファイルを修正 |
| `error: attribute 'bar' missing` | option 名違い | home-manager / nix-darwin の docs 確認 |
| `error: builder for '/nix/store/...' failed with exit code 1` | パッケージのビルド失敗 | ログを読み、必要ならパッケージを別系統（Brew / mise）に逃がす |
| `Error: Brewfile dependencies are not up to date` | Brewfile 不整合 | `brew bundle` を手動で走らせて様子見、または Brewfile 編集 |
| activation script の失敗 | スクリプト内のシェルエラー | スクリプト本体（`home/scripts.nix` 等）を修正 |

エラー出力の最後 50 行を読むのが基本。`nix-rebuild 2>&1 | tail -50` で抽出できる。

### push のタイミング

**rebuild が成功してから push する。**

理由: rebuild が失敗してから直すと、「失敗したコミット」が origin に残ってしまい、
他のマシンで pull したときに同じエラーを踏む。
ローカルで動作確認 → 成功確認後に push、が安全。

ただし、

- すでに push 済みのコミットを修正する場合 → push 前に rebase / fixup する選択肢もユーザーに提示
- pre-commit hook が失敗したら **新コミット**で修正（`--amend` は AGENTS.md で禁止扱い）

### 失敗時の挙動

修正できそうなら 1〜2 回まで自動で再試行する。それ以上ループするときはユーザーに状況を報告する。
無限ループを避けるため、同じエラーを 2 回連続で見たら必ずユーザーの判断を仰ぐ。

### 変更がない場合

`git status` がクリーンなのに依頼が来たケース：

- すでにコミット済みだが rebuild してないだけ → そのまま `nix-rebuild` を実行
- 既に rebuild 済みでも明示的に再実行したい場合がある → ユーザーに確認
- どちらも空振りなら「特に変更ないけど一応 rebuild します？」と聞く

## このスキル自体の動作確認

ドライランしたいときは：

```bash
git status
git diff
# どのファイルを add するつもりか宣言してからコミット
```

までを示し、ユーザーが OK したら実行に移る。Auto モード時は宣言と実行を併走しても良いが、
`git push` 直前は最終 diff を提示してから走る方が安全。
