# git add に関するルール

`git add -A` / `git add .` / `git add --all` を使わない。

これらの一括ステージングコマンドは、意図しないファイル（シークレット、ビルド成果物、今回の変更スコープ外のファイル）を巻き込む危険がある。必ずパスを明示して個別に add する。

```bash
git add path/to/file1 path/to/file2
```
