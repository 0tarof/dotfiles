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

eval "$(mise activate zsh --shims)"

# miseが追加したパスを一旦PATHから削除し、$HOME/binの後に再配置
path=(
    $HOME/bin(N-/)
    $path
)

# Homebrew Bundle
HOMEBREW_BUNDLE_FILE="$HOME/.dotfiles/Brewfile"

# Export environment variables
export PATH HOMEBREW_BUNDLE_FILE