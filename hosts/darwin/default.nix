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
      "manaflow-ai/cmux"
      "steipete/tap"
    ];

    # Brews - Nix に無いもの / macOS 固有のみ（CLI は原則 home.packages）
    brews = [
      "aws-sam-cli"       # AWS SAM CLI (macOS-specific build)
      "container"          # Apple Container runtime
      "html2markdown"     # Not in nixpkgs
      "mise"              # Runtime version manager
      "newrelic-cli"      # New Relic CLI
      "mysql-client@8.0"  # Versioned package
      "pinentry-mac"      # macOS-specific
      { name = "socktainer"; start_service = true; } # Docker-compatible socket for Apple Container
      "telnet"            # Removed from macOS base system
      "dlvhdr/formulae/diffnav"
    ];

    # Casks - GUI applications
    casks = [
      "adobe-creative-cloud"
      "affinity"
      "android-studio"
      "caffeine"
      "canva"
      "chatgpt"
      "claude"
      "cmux"
      "codex"
      "codex-app"
      "cursor"
      "deepl"
      "discord"
      "discord@ptb"
      "docker-desktop"
      "dotnet-sdk"
      "dropbox"
      "font-hackgen-nerd"
      "font-meslo-for-powerlevel10k"
      "font-migu-1p"
      "font-moralerspace"
      "font-noto-sans-cjk"
      "font-plemol-jp-nf"
      "font-source-han-code-jp"
      "font-source-han-sans-vf"
      "font-udev-gothic-nf"
      "gcloud-cli"
      "ghostty"
      "iterm2"
      "itermbrowserplugin"
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
      "steipete/tap/codexbar"
      "tableplus"
      "visual-studio-code"
      "vlc"
      "zed"
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

  # Enable sudo with Touch ID (reattach enables Touch ID inside tmux)
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;

  # git+ssh flake inputs are fetched by root during `sudo darwin-rebuild`,
  # and root has no ~/.ssh/known_hosts. Register GitHub's host key globally
  # (/etc/ssh/ssh_known_hosts) so host key verification succeeds.
  # Key from https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

  # ==========================================================================
  # Homebrew activation script override
  # ==========================================================================
  # Move homebrew bundle to postActivation so it runs AFTER home-manager
  # This ensures gh CLI is available for private tap authentication
  system.activationScripts.homebrew.text = lib.mkForce ''
    # Homebrew bundle moved to postActivation (after home-manager)
    # to ensure gh CLI is available for private taps
  '';

  system.activationScripts.postActivation.text = let
    cfg = config.homebrew;
    userProfileBin = "/etc/profiles/per-user/${username}/bin";
    userHomeBin = "/Users/${username}/bin";
    brewNames = map (b: if lib.isString b then b else b.name) cfg.brews;
    qualifiedBrews = lib.filter (lib.hasInfix "/") brewNames;
    caskNames = map (c: if lib.isString c then c else c.name) cfg.casks;
    qualifiedCasks = lib.filter (lib.hasInfix "/") caskNames;
    trustQualifiedBrewCommands = lib.concatMapStringsSep "\n" (brew: ''
          run_brew_as_user trust --formula ${lib.escapeShellArg brew} >/dev/null
    '') qualifiedBrews;
    trustQualifiedCaskCommands = lib.concatMapStringsSep "\n" (cask: ''
          run_brew_as_user trust --cask ${lib.escapeShellArg cask} >/dev/null
          # Some taps expose the same token as both a formula and a cask.
          run_brew_as_user trust --formula ${lib.escapeShellArg cask} >/dev/null || true
    '') qualifiedCasks;
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
      run_brew_as_user() {
        HOMEBREW_NO_AUTO_UPDATE=1 sudo \
          --preserve-env=HOMEBREW_GITHUB_API_TOKEN,HOMEBREW_NO_AUTO_UPDATE \
          --user=${lib.escapeShellArg cfg.user} \
          --set-home \
          "${cfg.brewPrefix}/brew" "$@"
      }

      # Trust configured taps (incl. overlay ones) before bundle.
      # New taps must be tapped before they can be trusted.
      # Older brew has no `trust` subcommand; skip in that case.
      if run_brew_as_user trust --help >/dev/null 2>&1; then
        for tap in ${lib.escapeShellArgs (map (t: if lib.isString t then t else t.name) cfg.taps)}; do
          run_brew_as_user tap "$tap" >/dev/null
          run_brew_as_user trust --tap "$tap" >/dev/null
        done
${trustQualifiedBrewCommands}
${trustQualifiedCaskCommands}
      fi
      
      PATH="${cfg.brewPrefix}:${lib.makeBinPath [ pkgs.mas ]}:${userProfileBin}:${userHomeBin}:$PATH" \
      HOMEBREW_GITHUB_API_TOKEN="$HOMEBREW_GITHUB_API_TOKEN" \
      sudo \
        --preserve-env=PATH,HOMEBREW_GITHUB_API_TOKEN \
        --user=${lib.escapeShellArg cfg.user} \
        --set-home \
        env \
        ${cfg.onActivation.brewBundleCmd} --cleanup --force
    else
      echo -e "\e[1;31merror: Homebrew is not installed, skipping...\e[0m" >&2
    fi
  '';
}
