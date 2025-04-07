{
  description = "Flake stores each individual package exact version in config file";

  inputs = {
    # Tells flake where to look for packages
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-24.11";
      };
    nixpkgs-unstable = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs"; # depents on nigxpkgs/must be the same
    };
    bindPkgs = {
      url = "github:NixOS/nixpkgs/3a641defd170a4ef25ce8c7c64cb13f91f867fca";
    };
    sambaPkgs = {
      url = "github:NixOS/nixpkgs/94c4dbe77c0740ebba36c173672ca15a7926c993";
    };
  };

  # Importing self ans nixpkgs
  outputs = { nixpkgs, nixpkgs-unstable, home-manager, bindPkgs, sambaPkgs, ...}:
    # Assagning nixpkgs.lib in the scope followed after brackets after in to variable lib
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {inherit system;};
      bindPkgs = import bindPkgs {inherit system;};
      sambaPkgs = import sambaPkgs {inherit system;};
    in {
    # Can specify multiple configurations
    nixosConfigurations = {
      # Any name to create system configuration, like assiging configuration object to a variable
      TufNix = lib.nixosSystem {
        # Architecture
        inherit system;
        # List/Array of modules
        modules = [ ./hosts/TufNix/configuration.nix ./users.nix ];
      };
      NixOSVMEFI = lib.nixosSystem {
        # Architecture
        inherit system;
        # List/Array of modules
        modules = [ ./hosts/NixOSVMEFI/configuration.nix ./users.nix ];
      };
      MainServer = lib.nixosSystem {
        # Architecture
        inherit system;
        # List/Array of modules
        modules = [ ./hosts/MainServer/configuration.nix ./users.nix ];
      };
      VMNixOSWork = lib.nixosSystem {
        # Architecture
        inherit system;
        specialArgs = { inherit bindPkgs sambaPkgs};
        # List/Array of modules
        modules = [ ./hosts/VMNixOSWork/configuration.nix ./users.nix ];
      };
    };
    homeConfigurations = {
      "keranod@TufNix" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          pkgsUnstable = nixpkgs-unstable.legacyPackages.${system};
        };
        modules = [
          ./common.nix ./hosts/TufNix/home.nix
        ];
      };
       "keranod@MainServer" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./common.nix ./hosts/MainServer/home.nix
        ];
      };
      "keranod@VMNixOSWork" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./common.nix ./hosts/VMNixOSWork/home.nix
        ];
      };
    };
  };
}
