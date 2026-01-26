# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repository for managing macOS/Linux development environment configurations using Nix, nix-darwin, and Home Manager.

## Commands

### Setup
```bash
# Initial installation (installs Nix, nix-darwin, Home Manager)
./bootstrap.sh

# Rebuild configuration after changes
nix-rebuild
```

### Git Operations
```bash
# Delete merged branches
bin/git-delete-merged-branch
```

## Architecture

### Directory Structure
- `bin/`: Utility scripts
- `zsh/`: Zsh theme file (.p10k.zsh)
- `home/`: Home Manager configuration
- `hosts/`: Host-specific configurations (darwin, linux)
- `overlay/`: Environment-specific configs (gitignored, e.g., work PC)
  - `overlay/nix/home.nix`: Environment-specific Home Manager config
  - `overlay/zsh/`: Environment-specific Zsh configurations
  - `overlay/bin/`: Environment-specific scripts
- `flake.nix`: Nix flake configuration

### Design Principles
1. **Declarative Management**: All packages and configs managed via Nix
2. **Environment Separation**: Base and environment-specific configs separated via `overlay/`
3. **Reproducibility**: Nix ensures consistent environments across machines
4. **Error Handling**: All scripts use `set -euo pipefail`

### Key Files
- `bootstrap.sh`: Initial Nix setup script
- `flake.nix`: Nix flake defining system configurations
- `home/default.nix`: Home Manager user configuration
- `hosts/darwin/default.nix`: macOS-specific system configuration (including Homebrew)
- `overlay/nix/home.nix`: Environment-specific Home Manager config (if exists)

### Nix Configuration
- **nix-darwin**: Manages macOS system settings and Homebrew
- **Home Manager**: Manages user packages and dotfiles
- **programs.zsh**: Declarative Zsh configuration with Antidote plugin manager

## Development Notes

1. Place new scripts in `bin/` with execute permissions
2. Add packages to `home/default.nix` under `home.packages`
3. Always place environment-specific configs in `overlay/`
4. Add proper error handling (`set -euo pipefail`) to scripts
5. **Commit before nix-rebuild**: Nix flake requires changes to be committed before `nix-rebuild` can see them (gitignored files are not accessible to flake)
6. Zsh overlay configs:
   - Create `overlay/zsh/.zshrc` for environment-specific shell config
   - Create `overlay/zsh/.zprofile` for environment-specific PATH/env setup
   - These files are automatically loaded by the main zsh configs
