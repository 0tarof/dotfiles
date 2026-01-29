{ config, lib, pkgs, username, ... }:

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
      "mysqlworkbench"
      "notion"
      "obs"
      "omnidisksweeper"
      "postman"
      "sequel-ace"
      "session-manager-plugin"
      "snowflake-snowsql"
      "tableplus"
      "visual-studio-code"
      "vlc"
    ];
  };

  # ==========================================================================
  # Zsh configuration
  # ==========================================================================
  programs.zsh.enable = true;

  # Nix daemon initialization in /etc/zshenv
  environment.etc."zshenv".text = ''
    # Nix
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    # End Nix
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

  # ==========================================================================
  # Homebrew activation script override
  # ==========================================================================
  # Move homebrew bundle to postActivation so it runs AFTER home-manager
  # This ensures ~/bin/gh-credential-helper exists for private tap authentication
  system.activationScripts.homebrew.text = lib.mkForce ''
    # Homebrew bundle moved to postActivation (after home-manager)
    # to ensure credential helper is available for private taps
  '';

  system.activationScripts.postActivation.text = let
    cfg = config.homebrew;
    userProfileBin = "/etc/profiles/per-user/${username}/bin";
    userHomeBin = "/Users/${username}/bin";
  in lib.mkAfter ''
    # Homebrew Bundle (moved here to run after home-manager activation)
    echo >&2 "Homebrew bundle..."
    if [ -f "${cfg.brewPrefix}/brew" ]; then
      # Get GitHub API token from gh CLI if available (for private taps)
      # Run as user since gh auth config is in user's home directory
      HOMEBREW_GITHUB_API_TOKEN=""
      if [ -x "${userProfileBin}/gh" ]; then
        HOMEBREW_GITHUB_API_TOKEN=$(sudo --user=${lib.escapeShellArg cfg.user} --set-home "${userProfileBin}/gh" auth token 2>/dev/null || true)
      fi
      
      PATH="${cfg.brewPrefix}:${lib.makeBinPath [ pkgs.mas ]}:${userProfileBin}:${userHomeBin}:$PATH" \
      HOMEBREW_GITHUB_API_TOKEN="$HOMEBREW_GITHUB_API_TOKEN" \
      sudo \
        --preserve-env=PATH,HOMEBREW_GITHUB_API_TOKEN \
        --user=${lib.escapeShellArg cfg.user} \
        --set-home \
        env \
        ${cfg.onActivation.brewBundleCmd}
    else
      echo -e "\e[1;31merror: Homebrew is not installed, skipping...\e[0m" >&2
    fi
  '';
}
