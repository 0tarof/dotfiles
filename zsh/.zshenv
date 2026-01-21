LANG=ja_JP.UTF-8

export LANG

# mise initialization (always loaded)
if command -v mise &> /dev/null; then
    eval "$(mise activate zsh)"
fi

# Ensure Nix paths are in PATH (mise may have overridden them)
# These paths are set by nix-darwin in /etc/zshenv but mise can override
typeset -U path PATH
path=(
    /etc/profiles/per-user/$USER/bin
    /run/current-system/sw/bin
    /nix/var/nix/profiles/default/bin
    $path
)
