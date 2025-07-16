- ssh to server
- login on user and root to change default password
- log back on user
- `home-manager switch --flake ~/.dotfiles`
- `cat ~/.dotfiles/.ssh/id_ed25519.pub` -> add on github
- git pull for any changes
- cd to ~/.dotfiles and git push

# VPN

- allow firewall connection on Hetzner for the same ports as in Nix config
- enable wireguard and the run below after

```bash
sudo su -
umask 077
mkdir /etc/wireguard
mkdir /etc/wireguard/clients
# generated server vpn keys once
wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub
# Client keys (name them per person/device)
wg genkey | tee /etc/wireguard/clients/client.key | wg pubkey > /etc/wireguard/clients/client.pub
```

- uncomment wireguard config otherwise will not work without above files
- push to GitHub and pull on the server
- on the server add clients by doing below

```bash
sudo su -
vi /home/keranod/.dotfiles/hosts/ABYSS/configuration.nix
:r /etc/wireguard/clients/myAndroid.pub
```

- move the pub key arnoud to fit in peers
- save and push to github
- rebuild nix

# HysteriaV2

- `sudo mkdir /var/www`
