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
    # Configuration loading with overlay support
    # ==========================================================================
    
    # Default configuration (for personal machines)
    defaultConfig = {
      system = "aarch64-darwin";
      username = "otaro";
      hostname = "personal-mac";
    };

    # Load config from environment variables (set by bootstrap.sh) or use defaults
    # This requires --impure flag
    envConfig = {
      system = let v = builtins.getEnv "NIX_DARWIN_SYSTEM"; in if v != "" then v else null;
      username = let v = builtins.getEnv "NIX_DARWIN_USERNAME"; in if v != "" then v else null;
      hostname = let v = builtins.getEnv "NIX_DARWIN_HOSTNAME"; in if v != "" then v else null;
    };

    # Merge: env vars override defaults
    config = defaultConfig // (builtins.removeAttrs envConfig (
      builtins.filter (k: envConfig.${k} == null) (builtins.attrNames envConfig)
    ));

    inherit (config) system username hostname;

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
            extraSpecialArgs = { inherit inputs username; };
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
