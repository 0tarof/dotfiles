#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
export BACKUP_DIR

# Source common functions
source "$SCRIPT_DIR/lib/functions.bash"

# Setup ZDOTDIR in appropriate zshenv file
setup_zdotdir() {
    local zshenv_content='export ZDOTDIR="$HOME"/.config/zsh'
    local zshenv_file=""
    
    # Check for zshenv in order of preference
    if [[ -d /etc/zsh ]]; then
        # Debian/Ubuntu/Arch style
        zshenv_file="/etc/zsh/zshenv"
    elif [[ -f /etc/zshenv ]]; then
        # macOS/RHEL/Amazon Linux/Fedora style (file already exists)
        zshenv_file="/etc/zshenv"
    else
        # Fallback: create /etc/zshenv if neither exists
        zshenv_file="/etc/zshenv"
        log_warning "No existing zshenv found, will create $zshenv_file"
    fi
    
    if [[ -f "$zshenv_file" ]] && grep -q "ZDOTDIR" "$zshenv_file"; then
        log_info "ZDOTDIR is already configured in $zshenv_file"
    else
        log_info "Setting up ZDOTDIR in $zshenv_file (requires sudo)..."
        if echo "$zshenv_content" | sudo tee -a "$zshenv_file" > /dev/null; then
            log_success "ZDOTDIR configured in $zshenv_file"
        else
            log_error "Failed to configure ZDOTDIR (sudo required)"
            log_warning "Please manually add to $zshenv_file: $zshenv_content"
            return 1
        fi
    fi
}

# Initialize git submodules
init_submodules() {
    log_info "Initializing git submodules..."
    if git submodule update --init --recursive; then
        log_success "Git submodules initialized successfully"
    else
        log_error "Failed to initialize git submodules"
        return 1
    fi
}

# Main installation function
main() {
    echo "=== Dotfiles Installation ==="
    echo "Script directory: $SCRIPT_DIR"
    echo ""
    
    # Initialize git submodules
    init_submodules
    echo ""
    
    # Setup ZDOTDIR
    log_info "Configuring ZDOTDIR..."
    setup_zdotdir
    echo ""
    
    # Configuration directories to install to ~/.config
    local -a config_dirs=(
        "zsh"
        "tmux"
        "git"
        "mise"
        "ghostty"
    )

    for config_dir in "${config_dirs[@]}"; do
        if [[ -d "$SCRIPT_DIR/$config_dir" ]]; then
            install_config_dir "$SCRIPT_DIR/$config_dir" "$config_dir"
            echo ""
        fi
    done

    # Git configuration file (special case with additional logging)
    if [[ -f "$SCRIPT_DIR/.gitconfig" ]]; then
        log_info "Installing Git configuration..."
        if create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig"; then
            log_info "Git user: $(git config --global user.name)"
            log_info "Git email: $(git config --global user.email)"
        fi
        echo ""
    fi

    # Bin scripts
    if [[ -d "$SCRIPT_DIR/bin" ]]; then
        install_bin_scripts "$SCRIPT_DIR/bin"
        echo ""
    fi

    # Claude Code configuration
    if [[ -d "$SCRIPT_DIR/claude" ]]; then
        install_subdirectories "$SCRIPT_DIR/claude" "$HOME/.claude" "commands" "skills"
        echo ""
    fi

    # Cursor configuration
    if [[ -d "$SCRIPT_DIR/cursor" ]]; then
        install_subdirectories "$SCRIPT_DIR/cursor" "$HOME/.cursor" "commands"
        echo ""
    fi
    
    # Add more dotfile installations here as needed
    # Example:
    # if [[ -f "$SCRIPT_DIR/.vimrc" ]]; then
    #     log_info "Installing Vim configuration..."
    #     create_symlink "$SCRIPT_DIR/.vimrc" "$HOME/.vimrc"
    #     echo ""
    # fi
    
    # Install Homebrew packages if brew-install is available
    if command -v brew &> /dev/null && [[ -x "$HOME/bin/brew-install" ]]; then
        log_info "Installing Homebrew packages from Brewfile..."
        if "$HOME/bin/brew-install"; then
            log_success "Homebrew packages installed successfully"
        else
            log_warning "Some Homebrew packages may have failed to install"
        fi
        echo ""
    fi
    
    echo "=== Installation Complete ==="
    
    if [[ -d "$BACKUP_DIR" ]]; then
        log_info "Backups saved to: $BACKUP_DIR"
    fi
    
    # Run overlay installation if exists
    if [[ -f "$SCRIPT_DIR/overlay/install.bash" ]]; then
        log_info "Running overlay installation..."
        echo ""
        "$SCRIPT_DIR/overlay/install.bash"
    fi
}

# Run main function
main "$@"