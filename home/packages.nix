# ==========================================================================
# Packages - CLI tools (migrated from Brewfile)
# ==========================================================================
{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  herdr = inputs.herdr.packages.${system}.default;
in
{
  home.packages = with pkgs; [
    # Version control & Git tools
    git
    git-lfs
    gh
    ghq
    git-filter-repo
    delta
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
    docker-client              # CLI のみ。daemon と cli-plugins は Docker Desktop
    docker-credential-helpers  # docker-credential-osxkeychain
    terraform
    kubectl
    k9s
    kind
    # helm  # Need Helm 4; locked nixpkgs is still 3.x → mise
    aws-cdk-cli                # 旧 nodePackages.aws-cdk（nodePackages は削除済み）
    auth0-cli
    # snowflake-cli  # Build fails in nixpkgs, keep in mise

    # Media
    ffmpeg
    yt-dlp
    imagemagick

    # Network
    wget

    # Converters
    html2text
    # html2markdown  # Not in nixpkgs, keep in Homebrew
    poppler-utils  # pdftotext, pdfinfo, pdftoppm などの PDF CLI ツール

    # Development tools
    # mise  # Keep in Homebrew for now (runtime version manager)
    devbox
    herdr
    qemu
    zellij
    uv
    pnpm
    sbt
  ];
}
