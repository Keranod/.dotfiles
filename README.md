# Links

- [MyNixOS Options](https://mynixos.com)
- [NixOS Packages](https://search.nixos.org/packages)

# Commands

- `nix-shell -p <packagename>` -> enable package for this shell only
- `sudo nixos-rebuild test` -> test build
- `sudo nixos-rebuild switch` -> rebuild distro and switch to it
- `sudo nixos-rebuild switch --flake <path to flake>#<flakename>` -> rebuil and switch to build using flake file and flakename
- `nix flake update` -> updates flake.lock file with wihtin directory containing it, updates just flake.lock not whole system
- `echo "<password>" | sudo tee <filename>` -> save password in plain text for pgadmin
- `sudo chmod 600 <filename>` -> make password only readable for root
- `nix-shell -p picutils && lspci` -> get pcis of devices
- `ls -ltrha /run/current-system/sw/bin | grep "<execname>"` -> find name of the package to use in module
- `ssh-keygen -R <ip or hostname>` -> remove remembered server of ip or hostname
- `df -h` -> check disk free space
- `top` or `htop` -> get system load
- `du -sh /nix/store` -> check how much space is used by nix store
- `sudo nix-collect-garbage -d` -> remove unused packages

# One line installer:

- disk check using `lsblk` and hostname needs to match name in hosts folder and confifuration.nix needs to be present in that folder
- if behind proxy add after `curl` `-x <proxy_url>:<port>`
- `curl -sSL https://github.com/keranod/.dotfiles/raw/main/semiAutoInstall.sh | sudo bash -s /dev/<disk name> <hostname>`
