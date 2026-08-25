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
      autoUpdate = false;
      # nix-darwin generates --force-cleanup which Homebrew 6.x removed.
      # Disable its cleanup and pass the correct flags via extraFlags.
      cleanup = "none";
      extraFlags = [ "--cleanup" "--force" "--zap" ];
      upgrade = false;
    };

    # Taps
    # Homebrew 6.0.0 で HOMEBREW_REQUIRE_TAP_TRUST が既定 ON になったため、
    # 非公式 tap は trusted を明示する（Brewfile に trusted: true が入る）。
    # brews / casks 側の trusted は既定 true なので指定不要。
    taps = [
      { name = "dlvhdr/formulae"; trusted = true; }
      { name = "manaflow-ai/cmux"; trusted = true; }
      { name = "steipete/tap"; trusted = true; }
    ];

    # Brews - Nix に無いもの / macOS 固有のみ（CLI は原則 home.packages）
    brews = [
      "auth0"             # Auth0 CLI (newer than locked nixpkgs)
      "aws-sam-cli"       # AWS SAM CLI (macOS-specific build)
      "container"          # Apple Container runtime
      "html2markdown"     # Not in nixpkgs
      "mise"              # Runtime version manager
      "newrelic-cli"      # New Relic CLI
      "mysql-client@8.0"  # Versioned package
      "pinentry-mac"      # macOS-specific
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
      "slack-cli"
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

}
