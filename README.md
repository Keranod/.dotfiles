# Links

- [MyNixOS Options](https://mynixos.com)
- [NixOS Packages](https://search.nixos.org/packages)

# Commands

- `sudo nixos-rebuild test` -> test build
- `sudo nixos-rebuild switch` -> rebuild distro and switch to it
- `sudo nixos-rebuild switch --flake <path to flake>#<flakename>` -> rebuil and switch to build using flake file and flakename
- `nix flake update` -> updates flake.lock file with wihtin directory containing it, updates just flake.lock not whole system
- `echo "<password>" | sudo tee <filename>` -> save password in plain text for pgadmin
- `sudo chmod 600 <filename>` -> make password only readable for root
