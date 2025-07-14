# Dotfiles

個人用の設定ファイル管理リポジトリ

## インストール

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.bash
```

## 環境別設定の使い方

会社PCなど、環境固有の設定を使いたい場合は`overlay/`ディレクトリを利用できます。

### 例：会社用Git設定の追加

1. 会社のdotfilesリポジトリをoverlay/にクローン
```bash
cd ~/.dotfiles
git clone https://github.com/COMPANY/dotfiles.git overlay
```

2. overlay/.gitconfigに会社用設定を配置
```gitconfig
[user]
    name = 会社での名前
    email = 会社のメールアドレス
```

この設定は自動的に読み込まれ、基本設定を上書きします。
`overlay/`ディレクトリは.gitignoreに含まれているため、個人リポジトリにはpushされません。

## Homebrew管理

Brewfileでパッケージを管理。インストール時に自動でパッケージもインストールされます。

- `brew-dump` - インストール済みパッケージをBrewfileに保存
- `brew-install` - Brewfileからパッケージをインストール  
- `brew-check` - Brewfileとの差分確認
- `brew-cleanup` - Brewfileにないパッケージを削除

## 構成

- `.gitconfig` - Git設定（基本設定）
- `install.bash` - インストールスクリプト
- `overlay/` - 環境固有の設定（gitignore対象）
- `Brewfile` - Homebrewパッケージリスト

## 設定の優先順位

1. 基本設定（このリポジトリの設定）
2. overlay/内の設定（存在する場合、基本設定を上書き）