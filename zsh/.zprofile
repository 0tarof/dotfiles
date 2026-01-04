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
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS specific paths
  path=(
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
export PATH HOMEBREW_BUNDLE_FILE HOMEBREW_PREFIX HOMEBREW_CELLAR HOMEBREW_REPOSITORY

# Load overlay configuration if exists
[[ -f ~/.config/zsh/overlay/.zprofile ]] && source ~/.config/zsh/overlay/.zprofile