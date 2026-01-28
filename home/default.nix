# ==========================================================================
# Home Manager configuration - Main entry point
# ==========================================================================
{ username, dotfilesDir, ... }:

let
  # Helper to optionally import overlay modules
  # Use absolute path from dotfilesDir because overlay/ is gitignored
  overlayPath = dotfilesDir + "/overlay/nix/home.nix";
  hasOverlay = builtins.pathExists overlayPath;
in
{
  # ==========================================================================
  # Basic configuration
  # ==========================================================================
  home.stateVersion = "24.11";
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ==========================================================================
  # Module imports
  # ==========================================================================
  imports = [
    ./shell.nix      # Zsh, Direnv
    ./packages.nix   # CLI tools
    ./dotfiles.nix   # Symlinks to config files
    ./scripts.nix    # Custom scripts, Claude Code installer
  ] 
  # Overlay (company-specific settings)
  ++ (if hasOverlay then [ overlayPath ] else [ ]);
}
