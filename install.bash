#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Create backup of existing file
backup_file() {
    local file="$1"
    if [[ -f "$file" ]] && [[ ! -L "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$BACKUP_DIR/$(basename "$file")"
        log_info "Backed up: $file -> $BACKUP_DIR/$(basename "$file")"
    fi
}

# Create symlink
create_symlink() {
    local source="$1"
    local target="$2"
    
    # Check if source exists (file or directory)
    if [[ ! -e "$source" ]]; then
        log_error "Source does not exist: $source"
        return 1
    fi
    
    # Backup existing file/directory
    if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$target" "$BACKUP_DIR/$(basename "$target")"
        log_info "Backed up: $target -> $BACKUP_DIR/$(basename "$target")"
    fi
    
    # Remove existing file or symlink
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        rm -rf "$target"
    fi
    
    # Create symlink
    ln -s "$source" "$target"
    
    # Verify symlink
    if [[ -L "$target" ]] && [[ -e "$target" ]]; then
        log_success "Created symlink: $target -> $source"
        return 0
    else
        log_error "Failed to create symlink: $target"
        return 1
    fi
}

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
}

# Run main function
main "$@"