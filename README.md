# Dotfiles

個人用の設定ファイル管理リポジトリ（Nix + nix-darwin + Home Manager）

## インストール

```bash
git clone https://github.com/0tarof/dotfiles.git ~/projects/github.com/0tarof/dotfiles
cd ~/projects/github.com/0tarof/dotfiles
./bootstrap.sh
```

## 設定の更新

```bash
# 設定ファイルを変更後、反映
nix-rebuild
```

## 環境別設定の使い方

会社PCなど、環境固有の設定を使いたい場合は`overlay/`ディレクトリを利用できます。

### 例：会社用設定の追加

1. 会社のdotfilesリポジトリをoverlay/にクローン
```bash
cd ~/projects/github.com/0tarof/dotfiles
git clone https://github.com/COMPANY/dotfiles.git overlay
```

2. overlay/nix/home.nix に環境固有のHome Manager設定を配置
```nix
{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    # 会社固有のパッケージ
  ];
}
```

この設定は自動的に読み込まれます。
`overlay/`ディレクトリは.gitignoreに含まれているため、個人リポジトリにはpushされません。

## 構成

### Nix設定
- `flake.nix` - Nix flake設定
- `home/default.nix` - Home Manager設定（ユーザーパッケージ、dotfiles）
- `hosts/darwin/default.nix` - macOS固有設定（Homebrew含む）

### その他
- `.gitconfig` - Git設定（基本設定）
- `bootstrap.sh` - 初期セットアップスクリプト
- `overlay/` - 環境固有の設定（gitignore対象）

## 管理方法

| 項目 | 管理方法 |
|------|----------|
| CLI ツール | `home.packages` (Nix) |
| GUI アプリ | `homebrew.casks` (nix-darwin) |
| Zsh 設定 | `programs.zsh` (Home Manager) |
| dotfiles | `home.file` (Home Manager) |
| macOS 設定 | nix-darwin |

## 設定の優先順位

1. 基本設定（このリポジトリの設定）
2. overlay/内の設定（存在する場合、基本設定を上書き）
