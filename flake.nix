{
  description = "0tarof's dotfiles with nix-darwin and home-manager";

  inputs = {
    # nixpkgs / nix-darwin / home-manager は同じリリース系列に揃える。ずれると
    # nix-darwin が eval 時に弾く。unstable 追従だと更新を溜めた分だけリリース境界を
    # 跨ぎ、3つ同時のメジャー移動になるため、リリースブランチで更新幅を区切る。
    # 版が新しいことを要求するものは mise / Homebrew 側に逃がしてある（README 参照）。
    # 次サイクルでは 3 つまとめて 26.11 系へ上げる。
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tirith = {
      # Use git+https instead of github: so Nix fetches the public repository
      # directly and avoids unauthenticated GitHub API rate limits during builds.
      url = "git+https://github.com/sheeki03/tirith";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herdr = {
      url = "git+ssh://git@github.com/ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, ... }:
  let
    # ==========================================================================
    # 環境変数経由での設定読み込み
    # ==========================================================================
    # 
    # なぜ環境変数を使うのか？
    # ------------------------
    # マシン固有の設定は .local/nix/config.nix に保存される（gitignore対象）。
    # Nix flake は --impure フラグを使っても、gitignore されたファイルには
    # 相対パス（./.local/nix/config.nix など）でアクセスできない。
    # 
    # そのため、nix-rebuild スクリプトが .local/nix/config.nix を読み込み、
    # 環境変数（NIX_SYSTEM, NIX_USERNAME, NIX_HOSTNAME）として渡す。
    # builtins.getEnv の使用には --impure フラグが必要。
    #
    # ※ `import ./.local/...` へのリファクタリングは不可能。
    #   gitignore されたファイルは flake のソースツリーに含まれないため。
    # ==========================================================================
    
    # デフォルト設定（個人マシン用）
    defaultConfig = {
      system = "aarch64-darwin";
      username = "otaro";
      hostname = "personal-mac";
    };

    # 環境変数から設定を読み込み、なければデフォルト値を使用
    getEnvOr = name: default:
      let val = builtins.getEnv name;
      in if val != "" then val else default;

    system = getEnvOr "NIX_SYSTEM" defaultConfig.system;
    username = getEnvOr "NIX_USERNAME" defaultConfig.username;
    hostname = getEnvOr "NIX_HOSTNAME" defaultConfig.hostname;

    # Dotfiles directory path (used for mkOutOfStoreSymlink and overlay imports)
    # builtins.toString ./. returns /nix/store/... path which doesn't contain gitignored files
    # So we use environment variable set by nix-rebuild script instead
    # --impure フラグが必要（既に環境変数読み込みで使用中）
    dotfilesDir = getEnvOr "DOTFILES_DIR" (builtins.toString ./.);

    # Helper to optionally import overlay modules
    # overlay/ is gitignored, so we must use absolute path with --impure
    # Nix module system accepts absolute path strings directly
    optionalOverlay = relativePath: 
      let absolutePath = dotfilesDir + "/" + relativePath;
      in if builtins.pathExists absolutePath
      then [ absolutePath ]
      else [ ];

    isDarwin = nixpkgs.lib.hasSuffix "-darwin" system;
    isLinux  = nixpkgs.lib.hasSuffix "-linux" system;

  in
  {
    # nix-darwin configuration (macOS only)
    darwinConfigurations = nixpkgs.lib.optionalAttrs isDarwin {
      ${hostname} = nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit inputs username; };
        modules = [
          ./hosts/darwin

          # home-manager module
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.${username} = import ./home;
              extraSpecialArgs = { inherit inputs username dotfilesDir; };
            };
          }
        ]
        # Overlay darwin configuration (company-specific)
        # Uses absolute path because overlay/ is gitignored
        ++ optionalOverlay "overlay/nix/darwin.nix";
      };
    };

    # Standalone home-manager configuration (Linux/WSL)
    homeConfigurations = nixpkgs.lib.optionalAttrs isLinux {
      "${username}@${hostname}" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
        modules = [
          ./home
        ]
        # Overlay home configuration (company-specific)
        ++ optionalOverlay "overlay/nix/home.nix";
        extraSpecialArgs = { inherit inputs username dotfilesDir; };
      };
    };

    # ==========================================================================
    # Convenience outputs
    # ==========================================================================

    # Allow running: nix run .#rebuild
    # This auto-detects the hostname
    apps.${system}.rebuild = nixpkgs.lib.optionalAttrs isDarwin {
      type = "app";
      program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "rebuild" ''
        darwin-rebuild switch --flake .#${hostname} "$@"
      '');
    };
  };
}
