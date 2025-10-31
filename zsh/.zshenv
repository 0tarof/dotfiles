LANG=ja_JP.UTF-8

export LANG

# mise initialization (always loaded)
if command -v mise &> /dev/null; then
    eval "$(mise activate zsh)"
fi
