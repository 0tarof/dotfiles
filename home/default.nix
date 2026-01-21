{ pkgs, username, ... }:

let
  # Helper to optionally import overlay modules
  overlayPath = ../overlay/nix/home.nix;
  hasOverlay = builtins.pathExists overlayPath;
in
{
  # Home Manager version
  home.stateVersion = "24.11";

  # User info
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ==========================================================================
  # Packages - minimal for now, more will be added in Phase 2
  # ==========================================================================
  home.packages = with pkgs; [
    # CLI tools will be added here in Phase 2
  ];

  # ==========================================================================
  # Dotfiles - symlink existing configurations
  # ==========================================================================
  # For now, we keep using the existing symlink-based setup from install.bash
  # In Phase 3, we can migrate to home.file for declarative management
  #
  # Example (Phase 3):
  # home.file.".config/zsh" = {
  #   source = ../../zsh;
  #   recursive = true;
  # };

  # ==========================================================================
  # Overlay imports (company-specific settings)
  # ==========================================================================
  imports = 
    if hasOverlay
    then [ overlayPath ]
    else [ ];
}
