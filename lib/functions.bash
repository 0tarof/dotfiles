#!/usr/bin/env bash

# Common functions for dotfiles installation

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
    local backup_dir="${BACKUP_DIR:-$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)}"
    
    if [[ -f "$file" ]] && [[ ! -L "$file" ]]; then
        mkdir -p "$backup_dir"
        cp "$file" "$backup_dir/$(basename "$file")"
        log_info "Backed up: $file -> $backup_dir/$(basename "$file")"
    fi
}

# Create symlink
create_symlink() {
    local source="$1"
    local target="$2"
    local backup_dir="${BACKUP_DIR:-$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)}"
    
    # Check if source exists (file or directory)
    if [[ ! -e "$source" ]]; then
        log_error "Source does not exist: $source"
        return 1
    fi
    
    # Backup existing file/directory
    if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        mkdir -p "$backup_dir"
        cp -r "$target" "$backup_dir/$(basename "$target")"
        log_info "Backed up: $target -> $backup_dir/$(basename "$target")"
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

# Install a configuration directory to ~/.config
# Usage: install_config_dir <source_dir> <config_name>
install_config_dir() {
    local source_dir="$1"
    local config_name="$2"

    if [[ ! -d "$source_dir" ]]; then
        log_warning "Source directory does not exist: $source_dir"
        return 1
    fi

    log_info "Installing ${config_name} configuration..."
    mkdir -p "$HOME/.config"
    create_symlink "$source_dir" "$HOME/.config/$config_name"
}

# Install executable scripts from a bin directory to ~/bin
# Usage: install_bin_scripts <source_bin_dir>
install_bin_scripts() {
    local source_bin_dir="$1"

    if [[ ! -d "$source_bin_dir" ]]; then
        log_warning "Source bin directory does not exist: $source_bin_dir"
        return 1
    fi

    log_info "Installing bin scripts..."

    # Create ~/bin directory if it doesn't exist
    if [[ ! -d "$HOME/bin" ]]; then
        mkdir -p "$HOME/bin"
        log_info "Created ~/bin directory"
    fi

    # Create symlinks for all executables
    local installed_count=0
    for file in "$source_bin_dir"/*; do
        if [[ -f "$file" ]] && [[ -x "$file" ]]; then
            local filename="$(basename "$file")"
            if create_symlink "$file" "$HOME/bin/$filename"; then
                ((installed_count++))
            fi
        fi
    done

    if [[ $installed_count -gt 0 ]]; then
        log_success "Installed $installed_count bin script(s)"
    fi
}

# Install multiple subdirectories from a parent directory
# Usage: install_subdirectories <source_parent> <target_parent> <subdirs...>
install_subdirectories() {
    local source_parent="$1"
    local target_parent="$2"
    shift 2
    local subdirs=("$@")

    if [[ ! -d "$source_parent" ]]; then
        log_warning "Source parent directory does not exist: $source_parent"
        return 1
    fi

    local parent_name="$(basename "$source_parent")"
    log_info "Installing ${parent_name} configuration..."
    mkdir -p "$target_parent"

    local installed_count=0
    for subdir in "${subdirs[@]}"; do
        if [[ -d "$source_parent/$subdir" ]]; then
            if create_symlink "$source_parent/$subdir" "$target_parent/$subdir"; then
                ((installed_count++))
            fi
        fi
    done

    if [[ $installed_count -gt 0 ]]; then
        log_success "Installed $installed_count ${parent_name} subdirectory(ies)"
    fi
}