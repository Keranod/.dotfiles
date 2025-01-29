# Links

- [MyNixOS](https://mynixos.com)

# Commands

- `sudo nixos-rebuild test` -> test build
- `sudo nixos-rebuild switch` -> rebuild distro and switch to it
- `sudo nixos-rebuild switch --flake <path to flake>#<flakename>` -> rebuil and switch to build using flake file and flakename
- `nix flake update` -> updates flake.lock file with wihtin directory containing it, updates just flake.lock not whole system
