{
  description = "0tarof's dotfiles with nix-darwin and home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
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

    # Dotfiles directory path (used for mkOutOfStoreSymlink)
    # builtins.toString ./. で flake.nix のあるディレクトリの絶対パスを取得
    # --impure フラグが必要（既に環境変数読み込みで使用中）
    dotfilesDir = builtins.toString ./.;

    # Helper to optionally import overlay modules
    optionalOverlay = path: 
      if builtins.pathExists path
      then [ path ]
      else [ ];

  in
  {
    # nix-darwin configuration
    darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
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
      ++ optionalOverlay ./overlay/nix/darwin.nix;
    };

    # ==========================================================================
    # Convenience outputs
    # ==========================================================================
    
    # Allow running: nix run .#rebuild
    # This auto-detects the hostname
    apps.${system}.rebuild = {
      type = "app";
      program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "rebuild" ''
        darwin-rebuild switch --flake .#${hostname} "$@"
      '');
    };
  };
}
