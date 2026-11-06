---
name: secret-leak-cleanup
description: リポジトリに誤ってコミットした認証情報（Webhook URL・API キー・トークン等）を、失効確認 → git 履歴の書き換え → GitHub Support への cached views / PR 参照の削除依頼まで対話的に進める。Use when the user says 「Webhook URL を漏らした」「APIキーをコミットしてしまった」「履歴から消したい」「認証情報の漏洩対応」「filter-repo」「cached views」「GitHub Support に起票」「refs/pull から消したい」, or asks to purge a leaked secret from a repository's history.
allowed-tools:
  - Bash(git log *)
  - Bash(git fetch *)
  - Bash(git for-each-ref *)
  - Bash(git rev-list *)
  - Bash(git clone --bare *)
  - Bash(git filter-repo *)
  - Bash(git status *)
  - Bash(mktemp *)
  - Bash(*check-revoked.sh *)
  - Bash(*find-leaks.sh *)
  - Bash(gh repo view *)
  - Bash(gh pr view *)
  - Bash(rg *)
  - Bash(jq *)
  - Read
  - Grep
user-invocable: true
---

# Secret Leak Cleanup

誤コミットした認証情報を、失効 → 履歴書き換え → GitHub 側のキャッシュ削除の順に片付ける。
会話は日本語で行う。**実際の URL・キー・SHA は、このスキルにも会話の出力にも書かない**（先頭をマスクして示す）。

## 付属スクリプト

このスキルの `scripts/` にある。対象リポジトリの作業ディレクトリで実行する。

- `scripts/check-revoked.sh [regex]`: 手順1の失効確認。引数なしは Slack Webhook、正規表現を渡すと他の URL にも使える。
- `scripts/find-leaks.sh <regex> [--fetch-prs]`: 手順2・4・6の件数確認。該当コミット数、該当 PR、SHA を出す（値そのものは出さない）。

## 大原則

- **失効が最優先。** 履歴を消しても、一度公開された値は漏れたものとして扱う。書き換えは失効の後。
- 破壊的操作（force push）と外部送信（Support への送信）は、実行前に内容を見せて必ずユーザーに確認する。
- `git add -A` / `.` / `--all` は使わず、パスを明示する。bare な `git push --force` は使わず、`--force-with-lease` をユーザー確認の上で使う。
- 作業中のリポジトリでは `filter-repo` を実行しない。必ず一時 clone で行う。
- JSON 処理は `jq`。Python ワンライナーは使わない。
- `filter-repo` による履歴書き換えは、ユーザーが明示的に頼んだ場合のみ行う。

## 1. 失効確認

履歴中の URL を抽出し、空ペイロードを POST して生死を判定する（`scripts/check-revoked.sh` が同じことをする）。メッセージは投稿されない。URL 全体は出さず先頭だけ表示する。

```bash
git log --all -p | grep -Eo 'https://hooks\.slack\.com/(services|workflows)/[A-Za-z0-9/_-]+' | sort -u | while read -r u; do
  printf '%s... -> ' "${u:0:50}"
  curl -s -m 10 -X POST -H 'Content-Type: application/json' -d '{}' -w ' [HTTP %{http_code}]\n' "$u"
done
```

| 応答 | 状態 |
|---|---|
| `no_service` / HTTP 404 | 失効済み |
| `no_text` / `invalid_payload` / HTTP 400 | **生存** |

生存していたら、先に発行元（Slack 等）で失効・再発行し、新しい値を secret に入れ直してもらう。完了を確認してから次へ進む。
Slack 以外（API キー等）は、発行元の失効手順と確認方法をユーザーと決める。

## 2. 現状把握

- 作業ツリー: `rg` で残存を確認する。
- 履歴: 何種類・何コミットに残るか数える（`git log --all -G'<regex>' --format=%H | wc -l`）。
- リモートの heads / tags / PR ref を分けて確認する。

## 3. 一時 clone で書き換え

```bash
export WORK=$(mktemp -d)
git clone --bare <repo-url> "$WORK/x.git"
cd "$WORK/x.git"
git filter-repo --replace-text <(printf '%s\n' 'regex:https://hooks\.slack\.com/services/[A-Za-z0-9/_-]+==>https://hooks.slack.com/services/REMOVED')
```

- 書き換え前後で件数を数えて検証する。
- **落とし穴:** リモートの heads がすでに書き換え済みのことがある。clone 直後の件数が 0 なら書き換えは不要で、残りは PR ref とローカルの古いブランチだけ。
- 古い履歴を持つローカルブランチを push すると値が復活する。`origin/main` へ rebase するか破棄する。
- push（`--force-with-lease`）は、対象ブランチと差分を見せてユーザー確認を取ってから行う。

## 4. PR ref の確認

`refs/pull/*` は push で消せないため、GitHub Support に頼むしかない。

```bash
git fetch origin '+refs/pull/*/head:refs/pull/*/head'
git log --all -G'<regex>' --format=%H                      # 該当 SHA
git for-each-ref --contains <sha> refs/pull                # 該当 PR
```

取得後に件数を数え、該当 SHA と PR を一覧にする。

## 5. GitHub Support への起票

- **`support.github.com/contact/private-information`（個人情報削除リクエスト）は使わない。** 他人が投稿した機密情報向けで、自分のリポジトリには合わない。公式ドキュメント「Removing sensitive data from a repository」の "Fully removing the data from GitHub" が正で、通常の Support portal から起票する。
- 流れ: `support.github.com/contact` → アカウント選択（組織）→ デプロイ種別 → 「リポジトリ」→ 件名と本文を入力。種別の「削除」は確証がない。選ぶと「Clear cached views」の仮想エージェント（バーチャルアシスタント）ボタンが出る。
- **本文に含める:** `owner/repo`、認証情報の種類と失効済みであること、影響 PR 数、First Changed Commit(s) または SHA 全件、LFS の有無、依頼内容（PR 参照の dereference・サーバー側 GC・cached views 削除）。
- **仮想エージェントは URL を1件ずつしか受け付けない。** SHA が多いときは代表1件でチケットを作り、残りはチケットのコメントで渡す。「PR に含まれるか」は `git for-each-ref --contains` の結果で正直に答える。
- 「Remove these pull requests」は **PR 本体が消えるので選ばない**。「Remove the commit references」を選ぶ。
- **1回目の依頼で PR ref を入れ忘れると**、GitHub は未参照コミットだけ消して終わる（実際に起きた）。最初から PR 参照の削除を依頼文に入れる。
- 件名は 80 文字が上限。チケット一覧は `support.github.com/tickets`。アーカイブ済みのチケットにはコメントできないので、その場合は新規チケットを起票する。
- 送信前に件名と本文の全文をユーザーに見せ、確認を取る。

## 6. 対応後の再確認

- PR ref を取り直し（手順4）、件数が 0 になったことを確認する。
- 認証情報入りの履歴を持つ一時 clone を消す: `rm -rf "$WORK"`
- 残件があれば、手順5の「入れ忘れ」を疑い、新規チケットを起票する。
