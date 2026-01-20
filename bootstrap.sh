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
# Darwin Rebuild
# =============================================================================
run_darwin_rebuild() {
    log_info "Running darwin-rebuild switch..."
    
    if ! command -v darwin-rebuild &> /dev/null; then
        # First time: use nix run
        log_info "First time setup: bootstrapping nix-darwin..."
        nix run nix-darwin -- switch --flake "$SCRIPT_DIR"
    else
        darwin-rebuild switch --flake "$SCRIPT_DIR"
    fi
    
    log_success "darwin-rebuild completed"
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo "=== Nix Bootstrap ==="
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
    
    # Run darwin-rebuild
    run_darwin_rebuild
    
    echo ""
    echo "=== Bootstrap Complete ==="
}

main "$@"
