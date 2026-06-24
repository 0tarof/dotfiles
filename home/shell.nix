# ==========================================================================
# Shell configuration - Zsh and Direnv
# ==========================================================================
{ lib, pkgs, username, ... }:

let
  antidotePlugins = [
    "romkatv/powerlevel10k"
    "zsh-users/zsh-completions"
    "zsh-users/zsh-syntax-highlighting"
    "zsh-users/zsh-autosuggestions"
    "zsh-users/zsh-history-substring-search"
  ];
  antidotePluginBundle = pkgs.writeText "hm_antidote-files" ''
    ${lib.concatStringsSep "\n" antidotePlugins}
  '';
  antidoteStaticHash = builtins.substring 0 12 (
    builtins.hashString "sha256" (lib.concatStringsSep "\n" antidotePlugins)
  );
in
{
  # ==========================================================================
  # Docker CLI completion - regenerate _docker on each rebuild
  # https://docs.docker.com/engine/cli/completion/
  # ==========================================================================
  home.activation.dockerCompletion = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ -z "''${DRY_RUN:-}" ]]; then
      for p in /opt/homebrew/bin/docker /usr/local/bin/docker; do
        if [[ -x "$p" ]]; then
          mkdir -p "$HOME/.docker/completions"
          "$p" completion zsh > "$HOME/.docker/completions/_docker"
          break
        fi
      done
    fi
  '';

  # ==========================================================================
  # mise completion - regenerate _mise on each rebuild
  # ==========================================================================
  home.activation.miseCompletion = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ -z "''${DRY_RUN:-}" ]]; then
      completions_dir="$HOME/.config/zsh/completions"

      run_with_aqua_github_token() {
        if [[ -n "''${AQUA_GITHUB_TOKEN:-}" && -n "''${GITHUB_TOKEN:-}" && -n "''${MISE_GITHUB_TOKEN:-}" ]]; then
          "$@"
          return
        fi

        for gh_path in /etc/profiles/per-user/${username}/bin/gh /run/current-system/sw/bin/gh /opt/homebrew/bin/gh /usr/local/bin/gh; do
          if [[ -x "$gh_path" ]]; then
            local token
            if [[ "$(id -u)" -eq 0 ]]; then
              token="$(sudo --user=${lib.escapeShellArg username} --set-home "$gh_path" auth token 2>/dev/null || true)"
            else
              token="$("$gh_path" auth token 2>/dev/null || true)"
            fi
            if [[ -n "$token" ]]; then
              AQUA_GITHUB_TOKEN="''${AQUA_GITHUB_TOKEN:-$token}" \
                GITHUB_TOKEN="''${GITHUB_TOKEN:-$token}" \
                MISE_GITHUB_TOKEN="''${MISE_GITHUB_TOKEN:-$token}" \
                "$@"
              return
            fi
          fi
        done

        "$@"
      }

      for p in /opt/homebrew/bin/mise /usr/local/bin/mise /etc/profiles/per-user/$USER/bin/mise /run/current-system/sw/bin/mise; do
        if [[ -x "$p" ]]; then
          mkdir -p "$completions_dir"
          if run_with_aqua_github_token "$p" completions zsh > "$completions_dir/_mise.tmp"; then
            mv "$completions_dir/_mise.tmp" "$completions_dir/_mise"
          else
            rm -f "$completions_dir/_mise.tmp"
          fi
          break
        fi
      done
    fi
  '';

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

      # Redirect pip to uv pip so UV_EXCLUDE_NEWER applies and we avoid
      # using pip directly (no min-release-age support on its own).
      pip = "uv pip";
      pip3 = "uv pip";
    };
    
    # Antidote is loaded manually below so non-TTY shells skip it entirely.
    
    # .zshenv content
    envExtra = ''
      LANG=ja_JP.UTF-8
      export LANG

      # Full mise activation reads project config and may print trust warnings.
      # Non-TTY shells only need quiet shims so command output stays clean.
      if command -v mise &> /dev/null; then
          if [[ -o interactive && -t 0 && -t 1 ]]; then
              eval "$(mise activate zsh --quiet)"
          else
              eval "$(mise activate zsh --shims --quiet)"
          fi
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
        if gh auth status &>/dev/null; then
          export HOMEBREW_GITHUB_API_TOKEN="$(gh auth token 2>/dev/null)"
        elif [[ -o interactive && -t 2 ]]; then
          print -u2 "gh: not authenticated. Run 'gh auth login' to enable Homebrew private tap access."
        fi
      fi

      HOMEBREW_BUNDLE_FILE="$HOME/projects/github.com/0tarof/dotfiles/Brewfile"
      export PATH HOMEBREW_BUNDLE_FILE HOMEBREW_PREFIX HOMEBREW_CELLAR HOMEBREW_REPOSITORY

      # Load overlay configuration if exists
      [[ -f ~/.config/zsh/overlay/.zprofile ]] && source ~/.config/zsh/overlay/.zprofile
    '';
    
    # .zshrc content
    initContent = lib.mkMerge [
      # Before compinit (p10k instant prompt must be at the very top)
      (lib.mkBefore ''
        __dotfiles_zsh_has_prompt_tty() {
          [[ -o interactive && -t 0 && -t 1 ]]
        }

        # Enable Powerlevel10k instant prompt only in real terminal sessions.
        if __dotfiles_zsh_has_prompt_tty && [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi

        # CLI completions generated by home.activation.*
        fpath=("$HOME/.config/zsh/completions" "$HOME/.docker/completions" $fpath)

        if __dotfiles_zsh_has_prompt_tty; then
          source ${pkgs.antidote}/share/antidote/antidote.zsh

          antidote_static_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
          antidote_static_file="$antidote_static_dir/antidote-${antidoteStaticHash}.zsh"
          mkdir -p "$antidote_static_dir"

          zstyle ':antidote:bundle' file ${antidotePluginBundle}
          zstyle ':antidote:static' file "$antidote_static_file"
          antidote load ${antidotePluginBundle} "$antidote_static_file"
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

        if __dotfiles_zsh_has_prompt_tty; then
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

          # Fix git core.bare=true caused by worktree + extensions.worktreeConfig
          # libgit2 (used by gitstatus/p10k) doesn't read .git/config.worktree,
          # so core.bare=true in .git/config breaks branch display.
          _fix_git_core_bare() {
            local git_dir
            git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return
            if [[ "$(git config --file "$git_dir/config" core.bare 2>/dev/null)" == "true" ]] \
              && [[ -d "$git_dir/refs" || -f "$git_dir/packed-refs" ]]; then
              git config --file "$git_dir/config" core.bare false
            fi
          }
          autoload -Uz add-zsh-hook
          add-zsh-hook chpwd _fix_git_core_bare
          _fix_git_core_bare  # 初回シェル起動時にも実行
        fi

        # Ensure $HOME/bin comes before mise shims in PATH
        typeset -U path PATH
        path=(
            $HOME/bin(N-/)
            ''${path:#$HOME/bin}
        )

        # Guard npm: require v11+ (for min-release-age support) and block
        # install shorthands so the deny rules / .npmrc cooldown are not
        # bypassed via `npm i`.
        npm() {
          local version major
          version="$(command npm --version 2>/dev/null)"
          major="''${version%%.*}"
          if [[ -z "$major" || "$major" -lt 11 ]]; then
            print -u2 "npm v11+ required for min-release-age (current: ''${version:-unknown})"
            return 1
          fi
          case "$1" in
            i|in|ins|inst|insta|instal|add)
              print -u2 "Use 'npm install' explicitly (alias '$1' is blocked)"
              return 1
              ;;
          esac
          command npm "$@"
        }

        # Load overlay configuration if exists
        [[ -f ~/.config/zsh/overlay/.zshrc ]] && source ~/.config/zsh/overlay/.zshrc
      ''
    ];
  };
}
