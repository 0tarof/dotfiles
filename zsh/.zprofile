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

# Prepend important paths while preserving existing PATH (including mise paths from .zshenv)
# Order: $HOME/bin > Nix paths > Homebrew paths > existing paths (mise, system, etc.)
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS specific paths to prepend
  path=(
    $HOME/bin(N-/)
    /etc/profiles/per-user/$USER/bin(N-/)
    /run/current-system/sw/bin(N-/)
    /nix/var/nix/profiles/default/bin(N-/)
    "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"(N-/)
    $HOMEBREW_PREFIX/opt/mysql-client@8.0/bin(N-/)
    $HOMEBREW_PREFIX/bin(N-/)
    $HOMEBREW_PREFIX/sbin(N-/)
    $path  # Preserve existing paths (mise, etc.)
  )
else
  # Linux paths to prepend
  path=(
    $HOME/bin(N-/)
    /etc/profiles/per-user/$USER/bin(N-/)
    /run/current-system/sw/bin(N-/)
    /nix/var/nix/profiles/default/bin(N-/)
    $HOMEBREW_PREFIX/bin(N-/)
    $HOMEBREW_PREFIX/sbin(N-/)
    $path  # Preserve existing paths (mise, etc.)
  )
fi

# miseは.zshenvで初期化済み、上記で$pathを保持しているのでmiseパスも維持される

if command -v gh &>/dev/null; then
  export HOMEBREW_GITHUB_API_TOKEN="$(gh auth token)"
fi

# Homebrew Bundle
HOMEBREW_BUNDLE_FILE="$HOME/.dotfiles/Brewfile"

# Export environment variables
export PATH HOMEBREW_BUNDLE_FILE HOMEBREW_PREFIX HOMEBREW_CELLAR HOMEBREW_REPOSITORY

# Load overlay configuration if exists
[[ -f ~/.config/zsh/overlay/.zprofile ]] && source ~/.config/zsh/overlay/.zprofile