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