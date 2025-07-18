typeset -U path PATH
path=(
$HOME/bin(N-/)
${ASDF_DATA_DIR:-$HOME/.asdf}/shims(N-/)
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

# Homebrew Bundle
HOMEBREW_BUNDLE_FILE="$HOME/.dotfiles/Brewfile"

# Export environment variables
export PATH HOMEBREW_BUNDLE_FILE