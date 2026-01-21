{ pkgs, username, ... }:

let
  # Helper to optionally import overlay modules
  overlayPath = ../overlay/nix/home.nix;
  hasOverlay = builtins.pathExists overlayPath;
in
{
  # Home Manager version
  home.stateVersion = "24.11";

  # User info
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ==========================================================================
  # Packages - CLI tools (migrated from Brewfile)
  # ==========================================================================
  home.packages = with pkgs; [
    # Version control & Git tools
    git
    gh
    ghq
    git-filter-repo
    gitleaks
    lefthook

    # Search & File tools
    bat
    fd
    ripgrep
    tree
    jq
    peco

    # Shell & Terminal
    zsh
    tmux
    direnv

    # Editors
    neovim
    vim

    # Cloud & DevOps
    awscli2
    # aws-sam-cli  # May need Homebrew for macOS
    terraform
    k9s

    # Media
    ffmpeg
    yt-dlp

    # Network
    wget

    # Converters
    html2text
    # html2markdown  # Not in nixpkgs, keep in Homebrew

    # Development tools
    # mise  # Keep in Homebrew for now (runtime version manager)
    # qemu  # Large, keep in Homebrew if needed
  ];

  # ==========================================================================
  # Custom scripts in ~/bin
  # ==========================================================================
  home.file."bin/nix-rebuild" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      DOTFILES_DIR="$HOME/projects/github.com/0tarof/dotfiles"
      CONFIG_FILE="$DOTFILES_DIR/.local/nix/config.nix"

      # Load config
      if [[ -f "$CONFIG_FILE" ]]; then
          system=$(grep 'system\s*=' "$CONFIG_FILE" | grep -v '^#' | sed 's/.*"\(.*\)".*/\1/')
          username=$(grep 'username\s*=' "$CONFIG_FILE" | grep -v '^#' | sed 's/.*"\(.*\)".*/\1/')
          hostname=$(grep 'hostname\s*=' "$CONFIG_FILE" | grep -v '^#' | sed 's/.*"\(.*\)".*/\1/')
      else
          echo "Error: Config not found. Run bootstrap.sh first."
          exit 1
      fi

      export NIX_DARWIN_SYSTEM="$system"
      export NIX_DARWIN_USERNAME="$username"
      export NIX_DARWIN_HOSTNAME="$hostname"

      echo "Rebuilding: $hostname ($system, user: $username)"
      
      sudo HOME="$HOME" \
          NIX_DARWIN_SYSTEM="$NIX_DARWIN_SYSTEM" \
          NIX_DARWIN_USERNAME="$NIX_DARWIN_USERNAME" \
          NIX_DARWIN_HOSTNAME="$NIX_DARWIN_HOSTNAME" \
          nix run nix-darwin -- switch --flake "$DOTFILES_DIR#$hostname" --impure
    '';
  };

  # Add ~/bin to PATH
  home.sessionPath = [ "$HOME/bin" ];

  # ==========================================================================
  # Dotfiles - symlink existing configurations
  # ==========================================================================
  # For now, we keep using the existing symlink-based setup from install.bash
  # In Phase 3, we can migrate to home.file for declarative management
  #
  # Example (Phase 3):
  # home.file.".config/zsh" = {
  #   source = ../../zsh;
  #   recursive = true;
  # };

  # ==========================================================================
  # Overlay imports (company-specific settings)
  # ==========================================================================
  imports = 
    if hasOverlay
    then [ overlayPath ]
    else [ ];
}
