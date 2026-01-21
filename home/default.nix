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
      
      # Use darwin-rebuild directly if available (faster than nix run)
      if command -v darwin-rebuild &> /dev/null; then
          sudo HOME="$HOME" \
              NIX_DARWIN_SYSTEM="$NIX_DARWIN_SYSTEM" \
              NIX_DARWIN_USERNAME="$NIX_DARWIN_USERNAME" \
              NIX_DARWIN_HOSTNAME="$NIX_DARWIN_HOSTNAME" \
              darwin-rebuild switch --flake "$DOTFILES_DIR#$hostname" --impure
      else
          # Fallback to nix run (first time or if darwin-rebuild not in PATH)
          sudo HOME="$HOME" \
              NIX_DARWIN_SYSTEM="$NIX_DARWIN_SYSTEM" \
              NIX_DARWIN_USERNAME="$NIX_DARWIN_USERNAME" \
              NIX_DARWIN_HOSTNAME="$NIX_DARWIN_HOSTNAME" \
              nix run nix-darwin -- switch --flake "$DOTFILES_DIR#$hostname" --impure
      fi
    '';
  };

  # Add ~/bin to PATH
  home.sessionPath = [ "$HOME/bin" ];

  # ==========================================================================
  # Dotfiles - declarative symlinks managed by Home Manager
  # ==========================================================================
  
  # Config directories -> ~/.config/*
  home.file.".config/zsh" = {
    source = ../zsh;
    recursive = true;
  };
  
  home.file.".config/tmux" = {
    source = ../tmux;
    recursive = true;
  };
  
  home.file.".config/git" = {
    source = ../git;
    recursive = true;
  };
  
  home.file.".config/mise" = {
    source = ../mise;
    recursive = true;
  };
  
  home.file.".config/ghostty" = {
    source = ../ghostty;
    recursive = true;
  };
  
  home.file.".config/nvim" = {
    source = ../nvim;
    recursive = true;
  };
  
  # Git config in home directory
  home.file.".gitconfig".source = ../.gitconfig;
  
  # Claude Code configuration
  home.file.".claude/commands" = {
    source = ../claude/commands;
    recursive = true;
  };
  
  home.file.".claude/skills" = {
    source = ../claude/skills;
    recursive = true;
  };
  
  home.file.".claude/rules" = {
    source = ../claude/rules;
    recursive = true;
  };
  
  home.file.".claude/settings.json".source = ../claude/settings.json;
  
  # Cursor configuration
  home.file.".cursor/commands" = {
    source = ../cursor/commands;
    recursive = true;
  };
  
  # Bin scripts (except nix-rebuild which is defined inline above)
  home.file."bin/brew-check" = {
    source = ../bin/brew-check;
    executable = true;
  };
  
  home.file."bin/brew-cleanup" = {
    source = ../bin/brew-cleanup;
    executable = true;
  };
  
  home.file."bin/brew-dump" = {
    source = ../bin/brew-dump;
    executable = true;
  };
  
  home.file."bin/brew-install" = {
    source = ../bin/brew-install;
    executable = true;
  };
  
  home.file."bin/ch" = {
    source = ../bin/ch;
    executable = true;
  };
  
  home.file."bin/git-delete-merged-branch" = {
    source = ../bin/git-delete-merged-branch;
    executable = true;
  };
  
  home.file."bin/gws" = {
    source = ../bin/gws;
    executable = true;
  };

  # ==========================================================================
  # Overlay imports (company-specific settings)
  # ==========================================================================
  imports = 
    if hasOverlay
    then [ overlayPath ]
    else [ ];
}
