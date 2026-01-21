{ pkgs, username, ... }:

{
  # Nix settings
  # Determinate Systems Nix manages the daemon, so we disable nix-darwin's management
  nix.enable = false;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System packages (minimal for now)
  environment.systemPackages = with pkgs; [
    # Basic tools - more will be added in Phase 2
  ];

  # ==========================================================================
  # Zsh configuration - ZDOTDIR setup
  # ==========================================================================
  programs.zsh = {
    enable = true;
    # This writes to /etc/zshenv
    interactiveShellInit = ''
      export ZDOTDIR="$HOME/.config/zsh"
    '';
  };

  # Create /etc/zshenv with ZDOTDIR
  environment.etc."zshenv".text = ''
    # Nix
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    # End Nix

    # ZDOTDIR - managed by nix-darwin
    export ZDOTDIR="$HOME/.config/zsh"
  '';

  # ==========================================================================
  # macOS system settings
  # ==========================================================================
  system = {
    # Used for backwards compatibility
    stateVersion = 6;
  };

  # The platform the configuration will be used on
  nixpkgs.hostPlatform = "aarch64-darwin";

  # User configuration
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # Enable sudo with Touch ID
  security.pam.services.sudo_local.touchIdAuth = true;
}
