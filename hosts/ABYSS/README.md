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
umask 077
# generated server vpn keys once
wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub
# Client keys (name them per person/device)
wg genkey | tee client.key | wg pubkey > client.pub
```

- uncomment wireguard config otherwise will not work without above files
