# Detect OS and set Homebrew path accordingly
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  HOMEBREW_PREFIX="/opt/homebrew"
  HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
  HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux
  HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
  HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
  HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX/Homebrew"
fi

typeset -U path PATH

# Nix paths (set by nix-darwin, must be preserved)
__nix_paths=(
  /etc/profiles/per-user/$USER/bin
  /run/current-system/sw/bin
  /nix/var/nix/profiles/default/bin
)

if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS specific paths
  path=(
  $HOME/bin(N-/)
  ${__nix_paths[@]}
  "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"(N-/)
  $HOMEBREW_PREFIX/opt/mysql-client@8.0/bin(N-/)
  $HOMEBREW_PREFIX/bin(N-/)
  $HOMEBREW_PREFIX/sbin(N-/)
  /usr/local/bin(N-/)
  /usr/local/sbin(N-/)
  /usr/bin
  /usr/sbin
  /bin
  /sbin
  /Library/Apple/usr/bin
  )
else
  # Linux paths
  path=(
  $HOME/bin(N-/)
  ${__nix_paths[@]}
  $HOMEBREW_PREFIX/bin(N-/)
  $HOMEBREW_PREFIX/sbin(N-/)
  /usr/local/bin(N-/)
  /usr/local/sbin(N-/)
  /usr/bin
  /usr/sbin
  /bin
  /sbin
  )
fi
unset __nix_paths

# miseは.zshenvで初期化済み、パスは上記で設定済み

if command -v gh &>/dev/null; then
  export HOMEBREW_GITHUB_API_TOKEN="$(gh auth token)"
fi

# Homebrew Bundle
HOMEBREW_BUNDLE_FILE="$HOME/.dotfiles/Brewfile"

# Export environment variables
export PATH HOMEBREW_BUNDLE_FILE HOMEBREW_PREFIX HOMEBREW_CELLAR HOMEBREW_REPOSITORY

# Load overlay configuration if exists
[[ -f ~/.config/zsh/overlay/.zprofile ]] && source ~/.config/zsh/overlay/.zprofile