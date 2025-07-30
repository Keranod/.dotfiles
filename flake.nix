{
  description = "Flake stores each individual package exact version in config file";

  inputs = {
    # Tells flake where to look for packages
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-25.05";
    };
    nixpkgs-unstable = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs"; # depents on nigxpkgs/must be the same
    };
    # For specific ones look readme how to get hash
    bindPkgs = {
      url = "github:NixOS/nixpkgs/3a641defd170a4ef25ce8c7c64cb13f91f867fca";
    };
    sambaPkgs = {
      url = "github:NixOS/nixpkgs/94c4dbe77c0740ebba36c173672ca15a7926c993";
    };
  };

  # Importing self ans nixpkgs
  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      bindPkgs,
      sambaPkgs,
      ...
    }:
    # Assagning nixpkgs.lib in the scope followed after brackets after in to variable lib
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
      inherit system;
        config = {
          allowUnfree = true;
        };
      };

      pkgsUnstable_ = import nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };

      bindPkgs_ = import bindPkgs { inherit system; };
      sambaPkgs_ = import sambaPkgs { inherit system; };
    in
    {
      # Can specify multiple configurations
      nixosConfigurations = {
        # Any name to create system configuration, like assiging configuration object to a variable
        TufNix = lib.nixosSystem {
          # Architecture
          inherit system;
          # List/Array of modules
          modules = [
            ./hosts/TufNix/configuration.nix
            ./modules/config/users.nix
            ./modules/config/commonConfig.nix
            ./modules/config/virtualBox.nix
          ];
        };
        MainServer = lib.nixosSystem {
          # Architecture
          inherit system;
          # List/Array of modules
          modules = [
            ./hosts/MainServer/configuration.nix
            ./modules/config/users.nix
            ./modules/config/commonConfig.nix
          ];
        };
        ABYSS = lib.nixosSystem {
          # Architecture
          inherit system;
          # List/Array of modules
          modules = [
            ./hosts/ABYSS/configuration.nix
            ./modules/config/users.nix
            ./modules/config/commonConfig.nix
          ];
        };
        VMNixOSWork = lib.nixosSystem {
          # Architecture
          inherit system;
          specialArgs = { inherit bindPkgs_ sambaPkgs_; };
          # List/Array of modules
          modules = [
            ./hosts/VMNixOSWork/configuration.nix
            ./modules/config/users.nix
            ./modules/config/commonConfig.nix
          ];
        };
        NetworkBox = lib.nixosSystem {
          # Architecture
          inherit system;
          # List/Array of modules
          modules = [
            ./hosts/NetworkBox/configuration.nix
            ./modules/config/users.nix
            ./modules/config/commonConfig.nix
          ];
        };
        FranzNix = lib.nixosSystem {
          # Architecture
          inherit system;
          # List/Array of modules
          modules = [
            ./hosts/FranzNix/configuration.nix
            ./modules/config/franzUsers.nix
            ./modules/config/virtualBox.nix
          ];
        };
      };
      homeConfigurations = {
        "keranod@TufNix" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit pkgsUnstable_; };
          modules = [
            ./modules/homeManager/gnome.nix
            ./modules/homeManager/commonHome.nix
            ./modules/homeManager/vscode.nix
            ./modules/homeManager/godot.nix
            ./hosts/TufNix/home.nix
          ];
        };
        "keranod@MainServer" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./modules/homeManager/commonHome.nix
            ./hosts/MainServer/home.nix
          ];
        };
        "keranod@ABYSS" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./modules/homeManager/commonHome.nix
            ./hosts/ABYSS/home.nix
          ];
        };
        "keranod@VMNixOSWork" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit pkgsUnstable_; };
          modules = [
            ./modules/homeManager/gnome.nix
            ./modules/homeManager/commonHome.nix
            ./modules/homeManager/vscode.nix
            ./hosts/VMNixOSWork/home.nix
          ];
        };
        "keranod@NetworkBox" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./modules/homeManager/commonHome.nix
            ./hosts/NetworkBox/home.nix
          ];
        };
        "franz@FranzNix" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./modules/homeManager/vscode.nix
            ./hosts/FranzNix/home.nix
          ];
        };
      };
    };
}
