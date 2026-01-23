# ==========================================================================
# Packages - CLI tools (migrated from Brewfile)
# ==========================================================================
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Version control & Git tools
    git
    gh
    ghq
    git-filter-repo
    gitleaks
    lefthook

    # Search & File tools
    bat
    fd
    ripgrep
    tree
    jq
    peco

    # Shell & Terminal
    # zsh  # Managed by programs.zsh
    tmux

    # Editors
    neovim
    vim

    # Cloud & DevOps
    awscli2
    # aws-sam-cli  # May need Homebrew for macOS
    terraform
    k9s
    nodePackages.aws-cdk
    # snowflake-cli  # Build fails in nixpkgs, keep in mise

    # Media
    ffmpeg
    yt-dlp

    # Network
    wget

    # Converters
    html2text
    # html2markdown  # Not in nixpkgs, keep in Homebrew

    # Development tools
    # mise  # Keep in Homebrew for now (runtime version manager)
    qemu
    zellij
    uv
    pnpm
  ];
}
