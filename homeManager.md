# Commands

- `home-manager switch --flake ~/.config/home-manager/#<username>` -> rebuild home-manager and switch to user config

# Steps

- install `home-manager` using configuration.nix and rebuliding with flake
- `home-manager init` -> initialise `home.nix` and generate `flake.nix`
- `cp -R ~/.config/home-manager ~/.dotfiles` -> copy home-manager file
- in `home.nix` file change nixpkgs url to the same as flake for system
- git add copied home-manager otherwise cannot build since when tracked by git and not staged then nixos refused to build using unstaged files
