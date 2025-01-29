{

  description = "Flake stores each individual package exact version in config file";

  inputs = {
    # Tells flake where to look for packages
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  # Importing self ans nixpkgs
  outputs = { self, nixpkgs, ...}:
    # Assagning nixpkgs.lib in the scope followed after brackets after in to variable lib
    let
      lib = nixpkgs.lib;
    in {
    # Can specify multiple configurations
    nixosConfigurations = {
      # Any name to create system configuration, like assiging configuration object to a variable
      nixos = lib.nixosSystem {
        # Architecture
	system = "x86_64-linux";
	# List/Array of modules
	modules = [ ./configuration.nix ];
      };
    };
  };

}
