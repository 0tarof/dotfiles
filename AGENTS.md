# AGENTS.md

このファイルは、Claude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## 概要

Nix、nix-darwin、Home Manager を使用して macOS/Linux 開発環境の設定を管理する個人用 dotfiles リポジトリです。

## コマンド

### セットアップ
```bash
# 初期インストール（Nix、nix-darwin、Home Manager をインストール）
./bootstrap.sh

# 設定変更後の再ビルド
nix-rebuild
```

### Git 操作
```bash
# マージ済みブランチの削除
bin/git-delete-merged-branch
```

## アーキテクチャ

### ディレクトリ構造
- `bin/`: ユーティリティスクリプト
- `zsh/`: Zsh テーマファイル (.p10k.zsh)
- `home/`: Home Manager 設定
- `hosts/`: ホスト固有の設定（darwin、linux）
- `overlay/`: 環境固有の設定（gitignore対象、例：会社PC）
  - `overlay/nix/home.nix`: 環境固有の Home Manager 設定
  - `overlay/zsh/`: 環境固有の Zsh 設定
  - `overlay/bin/`: 環境固有のスクリプト
- `flake.nix`: Nix flake 設定

### 設計原則
1. **宣言的管理**: すべてのパッケージと設定を Nix で管理
2. **環境分離**: ベースと環境固有の設定を `overlay/` で分離
3. **再現性**: Nix がマシン間で一貫した環境を保証
4. **エラーハンドリング**: すべてのスクリプトで `set -euo pipefail` を使用

### 主要ファイル
- `bootstrap.sh`: 初期 Nix セットアップスクリプト
- `flake.nix`: システム設定を定義する Nix flake
- `home/default.nix`: Home Manager ユーザー設定
- `hosts/darwin/default.nix`: macOS 固有のシステム設定（Homebrew を含む）
- `overlay/nix/home.nix`: 環境固有の Home Manager 設定（存在する場合）

### Nix 設定
- **nix-darwin**: macOS システム設定と Homebrew を管理
- **Home Manager**: ユーザーパッケージと dotfiles を管理
- **programs.zsh**: Antidote プラグインマネージャーを使用した宣言的 Zsh 設定

## 開発メモ

1. 新しいスクリプトは `bin/` に実行権限付きで配置
2. パッケージは `home/default.nix` の `home.packages` に追加
3. 環境固有の設定は必ず `overlay/` に配置
4. スクリプトには適切なエラーハンドリング（`set -euo pipefail`）を追加
5. **コミットしてから nix-rebuild**: Nix flake は変更がコミットされないと認識できない（gitignore されたファイルは flake からアクセス不可）
6. Zsh overlay 設定:
   - 環境固有のシェル設定は `overlay/zsh/.zshrc` を作成
   - 環境固有の PATH/env 設定は `overlay/zsh/.zprofile` を作成
   - これらのファイルはメインの zsh 設定から自動的に読み込まれる
7. **変更を入れたら動作確認を優先**: 設定変更後は謝罪や説明の前にまず `nix-rebuild` を実行して動作確認すること
