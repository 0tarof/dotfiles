typeset -U path PATH
path=(
"$HOME/Library/Application Support/JetBrains/Toolbox/scripts"(N-/)
/opt/homebrew/opt/mysql-client@8.0/bin(N-/)
/opt/homebrew/bin(N-/)
/opt/homebrew/sbin(N-/)
/usr/local/bin(N-/)
/usr/local/sbin(N-/)
/usr/bin
/usr/sbin
/bin
/sbin
/Library/Apple/usr/bin
)

# miseは.zshenvで初期化済み

# miseが追加したパスを一旦PATHから削除し、$HOME/binの後に再配置
path=(
    $HOME/bin(N-/)
    $path
)

if command -v gh &>/dev/null; then
  export HOMEBREW_GITHUB_API_TOKEN="$(gh auth token)"
fi

# Homebrew Bundle
HOMEBREW_BUNDLE_FILE="$HOME/.dotfiles/Brewfile"

# Export environment variables
export PATH HOMEBREW_BUNDLE_FILE

# Load overlay configuration if exists
[[ -f ~/.config/zsh/overlay/.zprofile ]] && source ~/.config/zsh/overlay/.zprofile