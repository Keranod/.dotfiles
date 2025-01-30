#!/bin/bash

# Ensure a disk name is provided
if [ -z "$1" ]; then
  echo "Specify disk to install on"
  echo "Check which one using 'lsblk'"
  echo "eg., /dev/sda or /dev/nvme0n1"
  exit 1
fi

DISK="$1"

# Ensure a hostname is provided
if [ -z "$2" ]; then
  echo "Specify the hostname (machine name)"
  exit 1
fi

HOSTNAME="$2"

# Partitioning (GPT, EFI)
echo "Partitioning $DISK..."
parted $DISK -- mklabel gpt
parted $DISK -- mkpart ESP fat32 1MiB 512MiB
parted $DISK -- set 1 esp on
parted $DISK -- mkpart primary ext4 512MiB 100%

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F 32 ${DISK}1
mkfs.ext4 ${DISK}2

# Mount partitions
echo "Mounting partitions..."
mount ${DISK}2 /mnt
mkdir -p /mnt/boot
mount ${DISK}1 /mnt/boot

echo "Partitioning and formatting complete."

# Install git and clone dotfiles
echo "Installing git and cloning dotfiles..."
nix-shell -p git && mkdir -p /mnt/home/keranod && git clone https://github.com/keranod/.dotfiles /mnt/home/keranod/.dotfiles

# Check if the hostname folder exists
if [ ! -d "/mnt/home/keranod/.dotfiles/hosts/$HOSTNAME" ]; then
  echo "Error: Host configuration for '$HOSTNAME' not found in .dotfiles/hosts/"
  exit 1
fi

# Check if configuration.nix exists for the hostname
if [ ! -f "/mnt/home/keranod/.dotfiles/hosts/$HOSTNAME/configuration.nix" ]; then
  echo "Error: configuration.nix not found for '$HOSTNAME'"
  exit 1
fi

# Generate configuration for NixOS
echo "Generating NixOS hardware configuration..."
mkdir -p /mnt/home/keranod/temp
rm -rf /mnt/keranod/.dotfiles/hosts/$HOSTNAME/hardware-configuration.nix
nixos-generate-config --root /mnt/keranod/.dotfiles/hosts/$HOSTNAME

# Start the NixOS installation
echo "Starting NixOS installation..."
nixos-install --flake /mnt/home/keranod/.dotfiles#$HOSTNAME

echo "NixOS installation complete."

# setup home-manager for keranod
nixos-enter --command "home-manager switch --flake /home/keranod/.dotfiles#keranod"
