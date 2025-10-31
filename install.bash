#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
export BACKUP_DIR

# Source common functions
source "$SCRIPT_DIR/lib/functions.bash"

# Setup ZDOTDIR in /etc/zshenv
setup_zdotdir() {
    local zshenv_content='export ZDOTDIR="$HOME"/.config/zsh'
    
    if [[ -f /etc/zshenv ]] && grep -q "ZDOTDIR" /etc/zshenv; then
        log_info "ZDOTDIR is already configured in /etc/zshenv"
    else
        log_info "Setting up ZDOTDIR in /etc/zshenv (requires sudo)..."
        if echo "$zshenv_content" | sudo tee -a /etc/zshenv > /dev/null; then
            log_success "ZDOTDIR configured in /etc/zshenv"
        else
            log_error "Failed to configure ZDOTDIR (sudo required)"
            log_warning "Please manually add to /etc/zshenv: $zshenv_content"
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
    
    # Zsh configuration
    if [[ -d "$SCRIPT_DIR/zsh" ]]; then
        log_info "Installing Zsh configuration..."
        mkdir -p "$HOME/.config"
        create_symlink "$SCRIPT_DIR/zsh" "$HOME/.config/zsh"
        echo ""
    fi
    
    # Git configuration
    if [[ -f "$SCRIPT_DIR/.gitconfig" ]]; then
        log_info "Installing Git configuration..."
        if create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig"; then
            log_info "Git user: $(git config --global user.name)"
            log_info "Git email: $(git config --global user.email)"
        fi
        echo ""
    fi
    
    # Git configuration directory
    if [[ -d "$SCRIPT_DIR/git" ]]; then
        log_info "Installing Git configuration directory..."
        mkdir -p "$HOME/.config"
        create_symlink "$SCRIPT_DIR/git" "$HOME/.config/git"
        echo ""
    fi
    
    # Mise configuration
    if [[ -d "$SCRIPT_DIR/mise" ]]; then
        log_info "Installing mise configuration..."
        mkdir -p "$HOME/.config"
        create_symlink "$SCRIPT_DIR/mise" "$HOME/.config/mise"
        echo ""
    fi
    
    # Bin scripts
    if [[ -d "$SCRIPT_DIR/bin" ]]; then
        log_info "Installing bin scripts..."

        # Create ~/bin directory if it doesn't exist
        if [[ ! -d "$HOME/bin" ]]; then
            mkdir -p "$HOME/bin"
            log_info "Created ~/bin directory"
        fi

        # Create symlinks for all executables in bin
        for file in "$SCRIPT_DIR/bin"/*; do
            if [[ -f "$file" ]] && [[ -x "$file" ]]; then
                local filename="$(basename "$file")"
                create_symlink "$file" "$HOME/bin/$filename"
            fi
        done
        echo ""
    fi

    # Claude Code configuration
    if [[ -d "$SCRIPT_DIR/claude" ]]; then
        log_info "Installing Claude Code configuration..."
        mkdir -p "$HOME/.claude"

        # Symlink commands directory
        if [[ -d "$SCRIPT_DIR/claude/commands" ]]; then
            create_symlink "$SCRIPT_DIR/claude/commands" "$HOME/.claude/commands"
        fi

        # Symlink skills directory
        if [[ -d "$SCRIPT_DIR/claude/skills" ]]; then
            create_symlink "$SCRIPT_DIR/claude/skills" "$HOME/.claude/skills"
        fi
        echo ""
    fi

    # Cursor configuration
    if [[ -d "$SCRIPT_DIR/cursor" ]]; then
        log_info "Installing Cursor configuration..."
        mkdir -p "$HOME/.cursor"

        # Symlink commands directory
        if [[ -d "$SCRIPT_DIR/cursor/commands" ]]; then
            create_symlink "$SCRIPT_DIR/cursor/commands" "$HOME/.cursor/commands"
        fi
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