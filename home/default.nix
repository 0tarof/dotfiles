{ config, lib, pkgs, username, ... }:

let
  # Helper to optionally import overlay modules
  overlayPath = ../overlay/nix/home.nix;
  hasOverlay = builtins.pathExists overlayPath;
  
  # Zsh overlay path
  zshOverlayPath = ../overlay/zsh;
  hasZshOverlay = builtins.pathExists zshOverlayPath;

  # ==========================================================================
  # Claude Code Installer Configuration
  # ==========================================================================
  # SHA256 of install.sh - update this when Anthropic updates the installer
  # To get the current hash: curl -fsSL https://claude.ai/install.sh | shasum -a 256
  claudeInstallSha256 = "363382bed8849f78692bd2f15167a1020e1f23e7da1476ab8808903b6bebae05";
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
  # Zsh - Declarative shell configuration
  # ==========================================================================
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    
    # History settings
    history = {
      size = 65536;
      save = 65536;
      path = "$HOME/.config/zsh/.zsh_history";
      extended = true;
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
    };
    
    # Shell options
    autocd = true;
    
    # Aliases
    shellAliases = {
      ll = "ls -la";
      la = "ls -a";
      l = "ls -CF";
    };
    
    # Antidote plugin manager
    antidote = {
      enable = true;
      plugins = [
        "romkatv/powerlevel10k"
        "zsh-users/zsh-completions"
        "zsh-users/zsh-syntax-highlighting"
        "zsh-users/zsh-autosuggestions"
        "zsh-users/zsh-history-substring-search"
        "wintermi/zsh-mise"
      ];
    };
    
    # .zshenv content
    envExtra = ''
      LANG=ja_JP.UTF-8
      export LANG

      # mise initialization (always loaded)
      if command -v mise &> /dev/null; then
          eval "$(mise activate zsh)"
      fi

      # Ensure Nix paths are in PATH (mise may have overridden them)
      typeset -U path PATH
      path=(
          /etc/profiles/per-user/$USER/bin
          /run/current-system/sw/bin
          /nix/var/nix/profiles/default/bin
          $path
      )
    '';
    
    # .zprofile content
    profileExtra = ''
      # Detect OS and set Homebrew path accordingly
      if [[ "$OSTYPE" == "darwin"* ]]; then
        HOMEBREW_PREFIX="/opt/homebrew"
        HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
        HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX"
      elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
        HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
        HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX/Homebrew"
      fi

      typeset -U path PATH

      # Prepend important paths while preserving existing PATH
      if [[ "$OSTYPE" == "darwin"* ]]; then
        path=(
          $HOME/bin(N-/)
          $HOME/.local/bin(N-/)
          /etc/profiles/per-user/$USER/bin(N-/)
          /run/current-system/sw/bin(N-/)
          /nix/var/nix/profiles/default/bin(N-/)
          "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"(N-/)
          $HOMEBREW_PREFIX/opt/mysql-client@8.0/bin(N-/)
          $HOMEBREW_PREFIX/bin(N-/)
          $HOMEBREW_PREFIX/sbin(N-/)
          $path
        )
      else
        path=(
          $HOME/bin(N-/)
          $HOME/.local/bin(N-/)
          /etc/profiles/per-user/$USER/bin(N-/)
          /run/current-system/sw/bin(N-/)
          /nix/var/nix/profiles/default/bin(N-/)
          $HOMEBREW_PREFIX/bin(N-/)
          $HOMEBREW_PREFIX/sbin(N-/)
          $path
        )
      fi

      if command -v gh &>/dev/null; then
        export HOMEBREW_GITHUB_API_TOKEN="$(gh auth token)"
      fi

      HOMEBREW_BUNDLE_FILE="$HOME/.dotfiles/Brewfile"
      export PATH HOMEBREW_BUNDLE_FILE HOMEBREW_PREFIX HOMEBREW_CELLAR HOMEBREW_REPOSITORY

      # Load overlay configuration if exists
      [[ -f ~/.config/zsh/overlay/.zprofile ]] && source ~/.config/zsh/overlay/.zprofile
    '';
    
    # .zshrc content
    initContent = lib.mkMerge [
      # Before compinit (p10k instant prompt must be at the very top)
      (lib.mkBefore ''
        # Enable Powerlevel10k instant prompt
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      
      # After compinit
      ''
        # Performance optimizations
        setopt PROMPT_SUBST
        setopt NO_BEEP
        setopt AUTO_PUSHD
        setopt PUSHD_IGNORE_DUPS
        setopt PUSHD_SILENT
        setopt HIST_VERIFY

        # Disable unnecessary features for faster startup
        DISABLE_AUTO_UPDATE="true"
        DISABLE_MAGIC_FUNCTIONS="true"

        # direnv integration
        eval "$(direnv hook zsh)"

        # asdf completion
        fpath=(''${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)

        # Autosuggestions settings
        ZSH_AUTOSUGGEST_STRATEGY=(history completion)
        ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

        # Key bindings for autosuggestions
        bindkey '^[[Z' autosuggest-accept  # Shift+Tab to accept suggestion

        # ghq + peco integration
        function peco-src () {
          local selected_dir=$(ghq list -p | peco --query "$LBUFFER")
          if [ -n "$selected_dir" ]; then
            BUFFER="cd ''${selected_dir}"
            zle accept-line
          fi
          zle clear-screen
        }
        zle -N peco-src
        bindkey '^]' peco-src

        # History search with peco
        function peco-history-selection() {
          BUFFER=`history -n 1 | tac | awk '!a[$0]++' | peco`
          CURSOR=$#BUFFER
          zle clear-screen
        }
        zle -N peco-history-selection
        bindkey '^r' peco-history-selection

        # To customize prompt, run `p10k configure` or edit ~/.config/zsh/.p10k.zsh.
        [[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh

        # Ensure $HOME/bin comes before mise shims in PATH
        typeset -U path PATH
        path=(
            $HOME/bin(N-/)
            ''${path:#$HOME/bin}
        )

        # Load overlay configuration if exists
        [[ -f ~/.config/zsh/overlay/.zshrc ]] && source ~/.config/zsh/overlay/.zshrc
      ''
    ];
  };

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
    # zsh  # Managed by programs.zsh
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
  # Claude Code Installation (via home.activation)
  # ==========================================================================
  # Dependencies required by claude install.sh
  home.activation.installClaudeCode = 
    let
      # Wrapper for shasum using coreutils sha256sum (works on both macOS and Linux)
      shasumWrapper = pkgs.writeShellScriptBin "shasum" ''
        # install.sh calls: shasum -a 256 <file>
        if [[ "$1" == "-a" && "$2" == "256" ]]; then
          shift 2
          ${pkgs.coreutils}/bin/sha256sum "$@"
        else
          echo "Unsupported shasum arguments: $*" >&2
          exit 1
        fi
      '';

      # install.sh requires: curl, sha256sum/shasum, grep, sed, awk, chmod, mkdir, etc.
      installerDeps = pkgs.buildEnv {
        name = "claude-installer-deps";
        paths = [
          pkgs.curl
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gawk
          pkgs.gnused
          shasumWrapper
        ];
      };
    in
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [[ -z "''${DRY_RUN:-}" ]]; then
        if command -v claude &> /dev/null; then
          # Already installed - just update
          $VERBOSE_ECHO "Claude Code already installed, checking for updates..."
          claude update 2>/dev/null || true
        else
          # Not installed - verify install.sh checksum before running
          $VERBOSE_ECHO "Installing Claude Code..."
          installer=$(mktemp)
          ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh -o "$installer" 2>/dev/null
          
          actual_sha=$(${pkgs.coreutils}/bin/sha256sum "$installer" | cut -d' ' -f1)
          if [[ "$actual_sha" != "${claudeInstallSha256}" ]]; then
            echo ""
            echo "============================================================"
            echo "WARNING: Claude install.sh checksum mismatch!"
            echo "============================================================"
            echo "Expected: ${claudeInstallSha256}"
            echo "Actual:   $actual_sha"
            echo ""
            echo "The installer script has been updated by Anthropic."
            echo "Please review the changes and update claudeInstallSha256 in:"
            echo "  home/default.nix"
            echo ""
            echo "To get the new hash:"
            echo "  curl -fsSL https://claude.ai/install.sh | shasum -a 256"
            echo ""
            echo "Or install manually:"
            echo "  curl -fsSL https://claude.ai/install.sh | bash"
            echo "============================================================"
            rm -f "$installer"
          else
            # Run install.sh with all required dependencies in PATH (pure Nix, no system deps)
            PATH="${installerDeps}/bin:$PATH" ${pkgs.bash}/bin/bash "$installer"
            rm -f "$installer"
          fi
        fi
      fi
    '';

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
  # Note: zsh is managed by programs.zsh, only p10k theme file is symlinked
  home.file.".config/zsh/.p10k.zsh".source = ../zsh/.p10k.zsh;
  
  # Overlay directory for company-specific zsh configs (if exists)
  home.file.".config/zsh/overlay" = lib.mkIf hasZshOverlay {
    source = zshOverlayPath;
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
