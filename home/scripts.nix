# ==========================================================================
# Custom scripts and activation hooks
# ==========================================================================
{ lib, pkgs, ... }:

let
  # ==========================================================================
  # Claude Code Installer Configuration
  # ==========================================================================
  # SHA256 of install.sh - update this when Anthropic updates the installer
  # To get the current hash: curl -fsSL https://claude.ai/install.sh | shasum -a 256
  claudeInstallSha256 = "363382bed8849f78692bd2f15167a1020e1f23e7da1476ab8808903b6bebae05";
in
{
  # ==========================================================================
  # Claude Code Installation (via home.activation)
  # ==========================================================================
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
          if [[ -n "''${VERBOSE_ECHO:-}" ]]; then
            claude_update_err="$(mktemp)"
            claude_update_status=0
            claude update 2>"$claude_update_err" || claude_update_status=$?
            if [[ "$claude_update_status" -ne 0 ]]; then
              $VERBOSE_ECHO "Claude update failed with exit code $claude_update_status. Error output:"
              cat "$claude_update_err" >&2
            fi
            rm -f "$claude_update_err"
          else
            claude update 2>/dev/null || true
          fi
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
            echo "  home/scripts.nix"
            echo ""
            echo "To get the new hash:"
            echo "  curl -fsSL https://claude.ai/install.sh | shasum -a 256"
            echo ""
            echo "Or install manually:"
            echo "  curl -fsSL https://claude.ai/install.sh | bash"
            echo "============================================================"
            rm -f "$installer"
            exit 1
          else
            # Run install.sh with all required dependencies in PATH (pure Nix, no system deps)
            PATH="${installerDeps}/bin:$PATH" ${pkgs.bash}/bin/bash "$installer"
            rm -f "$installer"
          fi
        fi
      fi
    '';

  # ==========================================================================
  # nix-rebuild: darwin-rebuild のラッパースクリプト
  # ==========================================================================
  # .local/nix/config.nix を読み込み、環境変数として flake.nix に渡す。
  # 
  # この設計が必要な理由：
  # - .local/ は gitignore 対象（マシン固有設定）
  # - Nix flake は gitignore されたファイルに相対パスでアクセスできない
  # - --impure でも `import ./.local/...` は失敗する
  # - 環境変数 + builtins.getEnv が唯一の方法
  #
  # 詳細は flake.nix のコメントを参照。
  # ==========================================================================
  home.file."bin/nix-rebuild" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      DOTFILES_DIR="$HOME/projects/github.com/0tarof/dotfiles"
      CONFIG_FILE="$DOTFILES_DIR/.local/nix/config.nix"

      get_config() {
          grep "$1\s*=" "$CONFIG_FILE" | grep -v '^#' | sed 's/.*"\(.*\)".*/\1/' | head -1
      }

      if [[ ! -f "$CONFIG_FILE" ]]; then
          echo "Error: Config not found. Run bootstrap.sh first."
          exit 1
      fi

      NIX_SYSTEM=$(get_config "system")
      NIX_USERNAME=$(get_config "username")
      NIX_HOSTNAME=$(get_config "hostname")

      echo "Rebuilding: $NIX_HOSTNAME"
      
      # --impure required: overlay/ is gitignored + builtins.getEnv usage
      if command -v darwin-rebuild &> /dev/null; then
          sudo HOME="$HOME" NIX_SYSTEM="$NIX_SYSTEM" NIX_USERNAME="$NIX_USERNAME" NIX_HOSTNAME="$NIX_HOSTNAME" \
              darwin-rebuild switch --flake "$DOTFILES_DIR#$NIX_HOSTNAME" --impure
      else
          sudo HOME="$HOME" NIX_SYSTEM="$NIX_SYSTEM" NIX_USERNAME="$NIX_USERNAME" NIX_HOSTNAME="$NIX_HOSTNAME" \
              nix run nix-darwin -- switch --flake "$DOTFILES_DIR#$NIX_HOSTNAME" --impure
      fi
    '';
  };

  # Add ~/bin to PATH
  home.sessionPath = [ "$HOME/bin" ];
}
