# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repository for managing macOS development environment configurations.

## Commands

### Setup
```bash
# Initial installation (creates symlinks and installs packages)
./install.bash
```

### Homebrew Management
```bash
# Save installed packages to Brewfile
bin/brew-dump

# Install packages from Brewfile
bin/brew-install

# Check differences between Brewfile and installed packages
bin/brew-check

# Remove unnecessary packages
bin/brew-cleanup
```

### Git Operations
```bash
# Delete merged branches
bin/git-delete-merged-branch
```

## Architecture

### Directory Structure
- `bin/`: Utility scripts
- `zsh/`: Zsh configs (uses Antidote plugin manager)
- `overlay/`: Environment-specific configs (gitignored, e.g., work PC)
- Root: Git config and Brewfile

### Design Principles
1. **Environment Separation**: Base and environment-specific configs separated via `overlay/`
2. **Declarative Management**: Homebrew packages managed via `Brewfile`
3. **Safety**: Backs up existing files during installation
4. **Error Handling**: All scripts use `set -euo pipefail`

### Key Files
- `install.bash`: Main setup script
- `Brewfile`: Base Homebrew package list
- `overlay/Brewfile`: Environment-specific packages (if exists)
- `zsh/.zshrc`: Main Zsh config

## Development Notes

1. Place new scripts in `bin/` with execute permissions
2. Run `bin/brew-dump` after Brewfile changes to sync
3. Always place environment-specific configs in `overlay/`
4. Add proper error handling (`set -euo pipefail`) to scripts