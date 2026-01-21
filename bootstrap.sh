#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Nix Installer Configuration
# =============================================================================
# renovate: datasource=github-releases depName=DeterminateSystems/nix-installer
readonly NIX_INSTALLER_VERSION="v3.15.1"
readonly NIX_INSTALLER_SHA256="e19eac62d6a7fb7c1ae595b36261ffd9ae6bee4583690baa391dc795b3096d5e"
readonly NIX_INSTALLER_URL="https://install.determinate.systems/nix/tag/${NIX_INSTALLER_VERSION}"

# =============================================================================
# Logging
# =============================================================================
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $*"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $*"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*"
}

# =============================================================================
# GitHub Token Setup (for API rate limit)
# =============================================================================
setup_github_token() {
    # Check if already set via environment
    if [[ -n "${NIX_CONFIG:-}" ]] && [[ "$NIX_CONFIG" == *"github.com"* ]]; then
        log_info "GitHub token already configured"
        return 0
    fi
    
    # Check if gh is available and authenticated
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        log_info "Using token from gh CLI..."
        local token
        token=$(gh auth token 2>/dev/null)
        if [[ -n "$token" ]]; then
            export NIX_CONFIG="access-tokens = github.com=$token"
            log_success "GitHub token configured from gh CLI (session only)"
            return 0
        fi
    fi
    
    # Prompt user for manual token input
    echo ""
    log_warning "GitHub API rate limit may cause issues during setup."
    echo ""
    echo "To avoid rate limiting, please create a temporary Personal Access Token:"
    echo "  1. Go to: https://github.com/settings/tokens/new"
    echo "  2. Create a token with NO scopes (public access only)"
    echo "  3. Set expiration to 1 day (we only need it for initial setup)"
    echo "  4. Copy the token"
    echo ""
    read -p "Paste your GitHub token (or press Enter to skip): " -s github_token
    echo ""
    
    if [[ -n "$github_token" ]]; then
        # Export for this session (used by Nix)
        export NIX_CONFIG="access-tokens = github.com=$github_token"
        # Mark that we're using a temporary token
        export DOTFILES_TEMP_GITHUB_TOKEN=1
        log_success "GitHub token configured for this session"
        log_info "Token is NOT saved to disk - it will be used only for this bootstrap"
    else
        log_warning "Skipping GitHub token setup. You may hit rate limits."
    fi
}

# =============================================================================
# Nix Installation
# =============================================================================
install_nix() {
    log_info "Downloading Nix installer ${NIX_INSTALLER_VERSION}..."
    
    local installer
    installer=$(mktemp)
    
    if ! curl --proto '=https' --tlsv1.2 -sSfL "$NIX_INSTALLER_URL" -o "$installer"; then
        log_error "Failed to download Nix installer"
        rm -f "$installer"
        return 1
    fi
    
    # Verify checksum
    log_info "Verifying checksum..."
    local actual_sha256
    actual_sha256=$(shasum -a 256 "$installer" | cut -d' ' -f1)
    
    if [[ "$actual_sha256" != "$NIX_INSTALLER_SHA256" ]]; then
        log_error "Checksum mismatch!"
        log_error "Expected: $NIX_INSTALLER_SHA256"
        log_error "Actual:   $actual_sha256"
        rm -f "$installer"
        return 1
    fi
    
    log_success "Checksum verified"
    
    # Run installer
    log_info "Installing Nix..."
    chmod +x "$installer"
    "$installer" install
    
    rm -f "$installer"
    log_success "Nix installed successfully"
}

# =============================================================================
# Configuration Detection & Generation
# =============================================================================
detect_system() {
    local arch
    arch=$(uname -m)
    local os
    os=$(uname -s)
    
    case "$os" in
        Darwin)
            case "$arch" in
                arm64) echo "aarch64-darwin" ;;
                x86_64) echo "x86_64-darwin" ;;
                *) echo "aarch64-darwin" ;;  # Default for unknown
            esac
            ;;
        Linux)
            case "$arch" in
                x86_64) echo "x86_64-linux" ;;
                aarch64) echo "aarch64-linux" ;;
                *) echo "x86_64-linux" ;;  # Default for unknown
            esac
            ;;
        *)
            echo "x86_64-linux"  # Default fallback
            ;;
    esac
}

detect_os_type() {
    case "$(uname -s)" in
        Darwin) echo "darwin" ;;
        *) echo "linux" ;;
    esac
}

ensure_config() {
    local config_dir="$SCRIPT_DIR/.local/nix"
    local config_file="$config_dir/config.nix"
    
    # If config already exists, use it
    if [[ -f "$config_file" ]]; then
        log_info "Using existing config: $config_file"
        return 0
    fi
    
    # Auto-generate config from system
    log_info "Generating Nix configuration from system info..."
    
    mkdir -p "$config_dir"
    
    local system username_val hostname_val os_type
    system=$(detect_system)
    username_val=$(whoami)
    hostname_val=$(hostname | sed 's/\.local$//')
    os_type=$(detect_os_type)
    
    cat > "$config_file" << EOF
# =============================================================================
# Auto-generated configuration
# =============================================================================
# Generated by bootstrap.sh on $(date)
# You can edit this file to customize your configuration.
# This file is in overlay/ so it won't be committed to the main repo.
# =============================================================================

{
  # System architecture
  system = "$system";

  # OS type: "darwin" or "linux"
  osType = "$os_type";

  # Your username on this machine
  username = "$username_val";

  # Hostname (used for nix-darwin/nixos configuration name)
  hostname = "$hostname_val";
}
EOF
    
    log_success "Generated config: $config_file"
    log_info "  system: $system"
    log_info "  osType: $os_type"
    log_info "  username: $username_val"
    log_info "  hostname: $hostname_val"
}

get_config_value() {
    local key="$1"
    local config_file="$SCRIPT_DIR/.local/nix/config.nix"
    
    if [[ -f "$config_file" ]]; then
        local value
        value=$(grep -v '^#' "$config_file" | grep "${key}\s*=" | sed 's/.*"\(.*\)".*/\1/' | head -1)
        if [[ -n "$value" ]]; then
            echo "$value"
            return
        fi
    fi
    
    echo ""
}

export_nix_config() {
    local config_file="$SCRIPT_DIR/.local/nix/config.nix"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi
    
    # Export config values as environment variables for Nix
    export NIX_DARWIN_SYSTEM=$(get_config_value "system")
    export NIX_DARWIN_USERNAME=$(get_config_value "username")
    export NIX_DARWIN_HOSTNAME=$(get_config_value "hostname")
    
    # Fallback to system detection if not in config
    [[ -z "$NIX_DARWIN_SYSTEM" ]] && export NIX_DARWIN_SYSTEM=$(detect_system)
    [[ -z "$NIX_DARWIN_USERNAME" ]] && export NIX_DARWIN_USERNAME=$(whoami)
    [[ -z "$NIX_DARWIN_HOSTNAME" ]] && export NIX_DARWIN_HOSTNAME=$(hostname | sed 's/\.local$//')
    
    log_info "Nix config: system=$NIX_DARWIN_SYSTEM, user=$NIX_DARWIN_USERNAME, host=$NIX_DARWIN_HOSTNAME"
}

get_hostname() {
    # Use exported variable if available, otherwise read from config
    if [[ -n "${NIX_DARWIN_HOSTNAME:-}" ]]; then
        echo "$NIX_DARWIN_HOSTNAME"
        return
    fi
    
    local value=$(get_config_value "hostname")
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        hostname | sed 's/\.local$//'
    fi
}

# =============================================================================
# Darwin Rebuild
# =============================================================================
run_darwin_rebuild() {
    local target_hostname
    target_hostname=$(get_hostname)
    
    log_info "Target hostname: $target_hostname"
    log_info "Running darwin-rebuild switch (requires sudo for system activation)..."
    
    # --impure is needed to read environment variables
    # sudo with explicit HOME and environment variables preserved
    local flake_ref="$SCRIPT_DIR#$target_hostname"
    local user_home="$HOME"
    
    if ! command -v darwin-rebuild &> /dev/null; then
        # First time: use nix run for darwin-rebuild
        log_info "First time setup: bootstrapping nix-darwin..."
        sudo HOME="$user_home" NIX_CONFIG="${NIX_CONFIG:-}" \
            NIX_DARWIN_SYSTEM="$NIX_DARWIN_SYSTEM" \
            NIX_DARWIN_USERNAME="$NIX_DARWIN_USERNAME" \
            NIX_DARWIN_HOSTNAME="$NIX_DARWIN_HOSTNAME" \
            nix run nix-darwin -- switch --flake "$flake_ref" --impure
    else
        sudo HOME="$user_home" NIX_CONFIG="${NIX_CONFIG:-}" \
            NIX_DARWIN_SYSTEM="$NIX_DARWIN_SYSTEM" \
            NIX_DARWIN_USERNAME="$NIX_DARWIN_USERNAME" \
            NIX_DARWIN_HOSTNAME="$NIX_DARWIN_HOSTNAME" \
            darwin-rebuild switch --flake "$flake_ref" --impure
    fi
    
    log_success "darwin-rebuild completed"
}

# =============================================================================
# Set Login Shell
# =============================================================================
set_login_shell() {
    local target_shell="/run/current-system/sw/bin/zsh"
    
    # Check if target shell exists
    if [[ ! -x "$target_shell" ]]; then
        log_info "Nix zsh not found at $target_shell, skipping login shell setup"
        return 0
    fi
    
    # Get current login shell
    local current_shell
    current_shell=$(dscl . -read /Users/"$USER" UserShell 2>/dev/null | awk '{print $2}')
    
    if [[ "$current_shell" == "$target_shell" ]]; then
        log_info "Login shell already set to $target_shell"
        return 0
    fi
    
    log_info "Setting login shell to $target_shell..."
    chsh -s "$target_shell"
    log_success "Login shell updated (will take effect in new terminal)"
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo "=== Nix Bootstrap ==="
    echo ""
    
    # Ensure configuration exists (auto-generate if needed)
    ensure_config
    echo ""
    
    # Setup GitHub token to avoid rate limiting
    setup_github_token
    echo ""
    
    # Check if Nix is installed
    if ! command -v nix &> /dev/null; then
        log_info "Nix is not installed"
        install_nix
        
        echo ""
        echo "=========================================="
        echo "Nix has been installed!"
        echo "Please restart your shell and run this script again."
        echo "=========================================="
        exit 0
    fi
    
    log_success "Nix is already installed"
    echo ""
    
    # Export config as environment variables for Nix
    export_nix_config
    echo ""
    
    # Run darwin-rebuild
    run_darwin_rebuild
    echo ""
    
    # Set login shell to Nix's zsh
    set_login_shell
    
    echo ""
    echo "=== Bootstrap Complete ==="
    
    # Remind user to delete temporary token if used
    if [[ "${DOTFILES_TEMP_GITHUB_TOKEN:-}" == "1" ]]; then
        echo ""
        log_info "Remember to delete your temporary GitHub token:"
        echo "  https://github.com/settings/tokens"
    fi
}

main "$@"
