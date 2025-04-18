# Links

- [MyNixOS Options](https://mynixos.com)
- [NixOS Packages](https://search.nixos.org/packages)
- [NixOS historical packages](https://www.nixhub.io/)

# Commands

- `nix flake update` - it if works do not fix it
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
- `journalctl -u strapi.service --since today` -> get lastest logs of strapi.service since today
- `ps aux | grep sshd` -> get all ssh sessions, first number after user is PID
- `nix flake metadata` -> get matadata about inputs, need to run in directory with flake

# One line installer:

- In `flake.nix` make sure to add machine in `nixosConfigurations` and user on the machine in `homeConfigurations`
- `PROXY` - add proxy settings in `configuration.nix` and `home.nix` otherwise no internet access after install and browser will not get internet and some other apps
- disk check using `lsblk` and hostname needs to match name in hosts folder and confifuration.nix needs to be present in that folder
- `PROXY` - if behind proxy add after `curl` `-x <proxy_url>:<port>`
- `curl -sSL https://github.com/keranod/.dotfiles/raw/main/semiAutoInstall.sh | sudo bash -s /dev/<disk name> <hostname> <optional proxy:port>`
- after install run on each user that has home-manager specific config on that user profile `home-manager switch --flake ~/.dotfiles`
- `PROXY` - after install and home manager done, change git origin for `~/.dotfiles` to use `https` instead `ssh` by first doing `git remote -v` and doing `git remote set-url origin https://github.com/username/reponame.git`
- remember one way or another `git add .` on new install in `~/.dotfiles` and `git push` to github
