{

  description = "Flake stores each individual package exact version in config file";

  inputs = {
    # Tells flake where to look for packages
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-24.11";
      };
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Importing self ans nixpkgs
  outputs = { nixpkgs, home-manager, ...}:
    # Assagning nixpkgs.lib in the scope followed after brackets after in to variable lib
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
    # Can specify multiple configurations
    nixosConfigurations = {
      # Any name to create system configuration, like assiging configuration object to a variable
      nixos = lib.nixosSystem {
        # Architecture
        inherit system;
        # List/Array of modules
        modules = [ ./configuration.nix ];
      };
    };
    homeConfigurations = {
      keranod = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    };
  };

}
