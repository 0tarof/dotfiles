# Dotfiles

個人用の設定ファイルを Nix、nix-darwin、Home Manager で管理するリポジトリです。

## インストール

```bash
git clone https://github.com/0tarof/dotfiles.git ~/projects/github.com/0tarof/dotfiles
cd ~/projects/github.com/0tarof/dotfiles
./bootstrap.sh
```

## 設定の反映

設定ファイルを変更したら `nix-rebuild` で反映します。
Nix flake は Git が追跡していないファイルを読まないため、新しく追加したファイルは先に `git add` してください。

```bash
nix-rebuild
```

## 環境固有の設定（overlay）

会社 PC だけで使う設定などは、このリポジトリに入れず `overlay/` ディレクトリに置きます。
`overlay/` は `.gitignore` の対象なので、個人リポジトリには push されません。

### 例：会社用の設定を追加する

1. 会社の dotfiles リポジトリを `overlay/` にクローンします。

   ```bash
   cd ~/projects/github.com/0tarof/dotfiles
   git clone https://github.com/COMPANY/dotfiles.git overlay
   ```

2. `overlay/nix/home.nix` に Home Manager の設定を置きます。macOS のシステム設定は `overlay/nix/darwin.nix` に置きます。

   ```nix
   { config, lib, pkgs, ... }:
   {
     home.packages = with pkgs; [
       # 会社固有のパッケージ
     ];
   }
   ```

どちらのファイルも、存在すれば `nix-rebuild` 時に読み込まれます。
overlay の設定は基本設定を置き換えるのではなく、Nix のモジュールとして基本設定に統合されます。
そのため `home.packages` のようなリストは連結されます。
一方、文字列や真偽値のような単一の値を両方で定義すると衝突してエラーになるので、overlay 側の値を優先したいときは `lib.mkForce` を付けます。

## 主なファイル

- `flake.nix`：flake の入口。macOS では nix-darwin、Linux では Home Manager 単体の構成を定義します
- `home/default.nix`：Home Manager の設定（ユーザーパッケージ、dotfiles の配置）
- `hosts/darwin/default.nix`：macOS 固有の設定（Homebrew を含む）
- `.gitconfig`：Git の基本設定
- `bootstrap.sh`：初期セットアップのスクリプト
- `overlay/`：環境固有の設定（Git の管理対象外）

## 何をどこで管理するか

| 対象 | 管理方法 |
|------|----------|
| ランタイム（Node、Go、Python など） | `mise`。グローバルの既定はパッチ版まで固定し、プロジェクトごとに上書きする |
| CLI ツール | `home.packages`（Nix）。nixpkgs に無いもの、版が古いもの、版を個別に固定したいものだけ mise か Homebrew |
| GUI アプリ | `homebrew.casks`（nix-darwin） |
| Zsh の設定 | `programs.zsh`（Home Manager） |
| dotfiles | `home.file`（Home Manager） |
| macOS の設定 | nix-darwin |
