{ pkgs, username, ... }:

{
  # Nix settings
  # Determinate Systems Nix manages the daemon, so we disable nix-darwin's management
  nix.enable = false;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # ==========================================================================
  # Homebrew - managed by nix-darwin
  # ==========================================================================
  homebrew = {
    enable = true;
    
    # Install Homebrew if not present
    onActivation = {
      autoUpdate = false;  # Don't auto-update on activation
      cleanup = "zap";     # Remove packages not in this list
      upgrade = false;     # Don't auto-upgrade
    };

    # Taps
    taps = [
      "dlvhdr/formulae"
      "homebrew/autoupdate"
    ];

    # Brews - packages not in Nixpkgs or macOS-specific
    brews = [
      "aws-sam-cli"       # AWS SAM CLI (macOS-specific build)
      "html2markdown"     # Not in nixpkgs
      "mise"              # Runtime version manager
      "mysql-client@8.0"  # Versioned package
      "pinentry-mac"      # macOS-specific
      "dlvhdr/formulae/diffnav"
    ];

    # Casks - GUI applications
    casks = [
      "adobe-creative-cloud"
      "affinity"
      "android-studio"
      "canva"
      "chatgpt"
      "claude"
      "cursor"
      "deepl"
      "discord"
      "discord@ptb"
      "docker-desktop"
      "dropbox"
      "font-meslo-for-powerlevel10k"
      "font-migu-1p"
      "font-noto-sans-cjk"
      "font-source-han-code-jp"
      "font-source-han-sans-vf"
      "gcloud-cli"
      "ghostty"
      "iterm2"
      "jetbrains-toolbox"
      "karabiner-elements"
      "microsoft-auto-update"
      "microsoft-office"
      "notion"
      "obs"
      "omnidisksweeper"
      "postman"
      "sequel-ace"
      "session-manager-plugin"
      "snowflake-snowsql"
      "visual-studio-code"
      "vlc"
    ];
  };

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
    # Required for homebrew and other user-specific options
    primaryUser = username;
  };

  # The platform the configuration will be used on
  nixpkgs.hostPlatform = "aarch64-darwin";

  # User configuration
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
    shell = pkgs.zsh;  # Use Nix's zsh as default shell
  };

  # Add Nix's zsh to /etc/shells
  environment.shells = [ pkgs.zsh ];

  # Enable sudo with Touch ID
  security.pam.services.sudo_local.touchIdAuth = true;
}
