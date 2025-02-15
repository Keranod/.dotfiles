# Commands

- `home-manager switch --flake ~/.dotfiles` -> username and machine pulled from current machine and user who is running, no need to specify as long as flake is using "username@hostname"

# Steps

- install `home-manager` using configuration.nix and rebuild with flake
- `home-manager init` -> initialise `home.nix` and generate `flake.nix`
- `cp ~/.config/home-manager/home.nix ~/.dotfiles` -> copy home.nix
- modify `flake.nix` to make it work
- git add copied home-manager otherwise cannot build since when tracked by git and not staged then nixos refused to build using unstaged files
