# This command gives you a temporary shell with the sops and age tools

`nix-shell -p sops age`

# Create a dedicated directory for key

`sudo mkdir -p /etc/nixos/sops-keys`
`sudo age-keygen -o /etc/nixos/sops-keys/key`

# Create a temporary file with your secrets

`echo "shadowsocks_password: \"your-test-password\"" > /tmp/secrets.yaml`

# Encrypt the file using the public key you copied earlier

`sudo su`
`sops --encrypt --age <YOUR_PUBLIC_KEY> /tmp/secrets.yaml > <config folder>/secrets.yaml.enc`
`exit`
`rm -rf /tmp/secrets.yaml`
