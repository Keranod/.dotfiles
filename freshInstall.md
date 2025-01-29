# Guide:
- [Flakes](https://www.youtube.com/watch?v=ACybVzRvDh)

# Steps:
- `nix.settings.experimental-features = [ "nix-command" "flakes" ];` -> add at the end of `/etc/nixos/configuration.nix` in the scope using `sudo nano /etc/nixos/configuration.nix` and rebuild
- `mkdirx ~/.dotfiles` -> create `.dotfiles` directory in user home directory
- `cp -R /etc/nixos/. ~/.dotfiles` -> copy config files to the newly created directory
- `nano ~/.dotfiles/flake.nix` -> create and edit `flake.nix` file
- configure flake/get temp flake
- `sudo nixos-rebuild switch --flake ~/.dotfiles` -> rebuild and switch to build using specified flake file
- create git repo to track changes and send to github
