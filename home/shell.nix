# ==========================================================================
# Shell configuration - Zsh and Direnv
# ==========================================================================
{ lib, ... }:

{
  # ==========================================================================
  # Direnv - 宣言的に管理、nix-direnv で Nix 開発環境を高速化
  # ==========================================================================
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;  # use nix-shell キャッシュで高速化
  };

  # ==========================================================================
  # Zsh - Declarative shell configuration
  # ==========================================================================
  programs.zsh = {
    enable = true;
    # dotDir is not set - use default ~/.zshrc, ~/.zshenv, etc.
    
    # History settings
    history = {
      size = 65536;
      save = 65536;
      path = "$HOME/.zsh_history";
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
}
