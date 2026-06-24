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
        if [[ -x "$HOME/.local/bin/claude" ]]; then
          # Already installed - just update
          $VERBOSE_ECHO "Claude Code already installed, checking for updates..."
          if [[ -n "''${VERBOSE_ECHO:-}" ]]; then
            claude_update_err="$(mktemp)"
            claude_update_status=0
            PATH="$HOME/.local/bin:$PATH" claude update 2>"$claude_update_err" || claude_update_status=$?
            if [[ "$claude_update_status" -ne 0 ]]; then
              $VERBOSE_ECHO "Claude update failed with exit code $claude_update_status. Error output:"
              cat "$claude_update_err" >&2
            fi
            rm -f "$claude_update_err"
          else
            PATH="$HOME/.local/bin:$PATH" claude update 2>/dev/null || true
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
            # Include ~/.local/bin so installer doesn't warn about PATH
            PATH="$HOME/.local/bin:${installerDeps}/bin:$PATH" ${pkgs.bash}/bin/bash "$installer"
            rm -f "$installer"
          fi
        fi
      fi
    '';

  # ==========================================================================
  # Helm plugin synchronization
  # ==========================================================================
  home.file."bin/sync-helm-plugins" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      helm_unittest_source="https://github.com/helm-unittest/helm-unittest.git"
      helm_unittest_version="1.1.1"

      run_helm() {
          mise exec -- helm "$@"
      }

      if ! command -v mise &> /dev/null; then
          echo "mise is not installed, skipping Helm plugin sync."
          exit 0
      fi

      if ! run_helm version --short &> /dev/null; then
          echo "Helm is not available via mise, skipping Helm plugin sync."
          exit 0
      fi

      current_version="$(run_helm plugin list 2>/dev/null | awk '$1 == "unittest" {print $2; exit}')"
      if [[ "$current_version" == "$helm_unittest_version" ]]; then
          echo "helm-unittest $helm_unittest_version is installed."
          exit 0
      fi

      if [[ -n "$current_version" ]]; then
          echo "Reinstalling helm-unittest plugin ($current_version -> $helm_unittest_version)..."
          run_helm plugin uninstall unittest > /dev/null || true
      else
          echo "Installing helm-unittest plugin $helm_unittest_version..."
      fi

      run_helm plugin install "$helm_unittest_source" --version "$helm_unittest_version" --verify=false
    '';
  };

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

      UPGRADE=0
      for arg in "$@"; do
          case "$arg" in
              -u|--upgrade)
                  UPGRADE=1
                  ;;
              -h|--help)
                  cat <<'USAGE'
      Usage: nix-rebuild [--upgrade]

        --upgrade, -u  Run `brew upgrade` after the rebuild to update
                       Homebrew formulae and casks.
        --help, -h     Show this help.
      USAGE
                  exit 0
                  ;;
              *)
                  echo "Unknown option: $arg" >&2
                  exit 2
                  ;;
          esac
      done

      DOTFILES_DIR="$HOME/projects/github.com/0tarof/dotfiles"
      CONFIG_FILE="$DOTFILES_DIR/.local/nix/config.nix"

      get_config() {
          grep "$1\s*=" "$CONFIG_FILE" | grep -v '^#' | sed 's/.*"\(.*\)".*/\1/' | head -1
      }

      run_with_aqua_github_token() {
          if [[ -n "''${AQUA_GITHUB_TOKEN:-}" ]]; then
              "$@"
              return
          fi

          if command -v gh &> /dev/null && gh auth status &> /dev/null; then
              local token
              token="$(gh auth token 2>/dev/null || true)"
              if [[ -n "$token" ]]; then
                  AQUA_GITHUB_TOKEN="$token" "$@"
                  return
              fi
          fi

          "$@"
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
      # DOTFILES_DIR is passed so flake can access gitignored overlay/ files
      if [[ "$(uname -s)" == "Darwin" ]]; then
          if command -v darwin-rebuild &> /dev/null; then
              sudo HOME="$HOME" DOTFILES_DIR="$DOTFILES_DIR" NIX_SYSTEM="$NIX_SYSTEM" NIX_USERNAME="$NIX_USERNAME" NIX_HOSTNAME="$NIX_HOSTNAME" \
                  darwin-rebuild switch --flake "$DOTFILES_DIR#$NIX_HOSTNAME" --impure
          else
              sudo HOME="$HOME" DOTFILES_DIR="$DOTFILES_DIR" NIX_SYSTEM="$NIX_SYSTEM" NIX_USERNAME="$NIX_USERNAME" NIX_HOSTNAME="$NIX_HOSTNAME" \
                  nix run nix-darwin -- switch --flake "$DOTFILES_DIR#$NIX_HOSTNAME" --impure
          fi
      else
          # Linux/WSL: standalone home-manager (no sudo needed)
          HOME="$HOME" DOTFILES_DIR="$DOTFILES_DIR" NIX_SYSTEM="$NIX_SYSTEM" NIX_USERNAME="$NIX_USERNAME" NIX_HOSTNAME="$NIX_HOSTNAME" \
              home-manager switch --flake "$DOTFILES_DIR#$NIX_USERNAME@$NIX_HOSTNAME" --impure
      fi

      if [[ "$UPGRADE" == "1" ]] && command -v brew &> /dev/null; then
          echo "Upgrading Homebrew packages..."
          brew upgrade
      fi

      echo "Installing mise tools..."
      run_with_aqua_github_token mise install

      echo "Installing Helm plugins..."
      if [[ -x "$HOME/bin/sync-helm-plugins" ]]; then
          "$HOME/bin/sync-helm-plugins"
      else
          echo "sync-helm-plugins not found, skipping."
      fi
    '';
  };

  # Add ~/bin to PATH
  home.sessionPath = [ "$HOME/bin" ];
}
