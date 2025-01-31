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

# Wipe the disk (destroy all existing partitions)
echo "Wiping disk $DISK..."
parted $DISK -- mklabel gpt --yes

# Partitioning (GPT, EFI)
echo "Partitioning $DISK..."
parted $DISK -- mklabel gpt
parted $DISK -- mkpart ESP fat32 1MiB 512MiB
parted $DISK -- set 1 esp on
parted $DISK -- mkpart primary ext4 512MiB 100%

if [ ! -b ${DISK}1 ] || [ ! -b ${DISK}2 ]; then
  echo "Partitions ${DISK}1 or ${DISK}2 do not exist. Exiting."
  exit 1
fi

echo "Formatting and labeling partitions..."
mkfs.fat -F 32 ${DISK}1
fatlabel ${DISK}1 NIXBOOT
mkfs.ext4 ${DISK}2 -L NIXROOT

# Mount partitions
echo "Mounting partitions..."
mount /dev/disk/by-label/NIXROOT /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/NIXBOOT /mnt/boot

# Check if both /mnt and /mnt/boot are mounted successfully
if mount | grep -q "/mnt" && mount | grep -q "/mnt/boot"; then
  echo "Both root and EFI partitions mounted successfully."
else
  echo "Failed to mount root or EFI partition."
  exit 1
fi

echo "Partitioning and formatting complete."

echo "Creating swap file"
dd if=/dev/zero of=/mnt/.swapfile bs=1024 count=2097152 # 2GB size
chmod 600 /mnt/.swapfile
mkswap /mnt/.swapfile
swapon /mnt/.swapfile

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
echo "Generating NixOS and modyfying configuration..."
nixos-generate-config --root /mnt

# Define the path to your NixOS configuration
CONFIG_PATH="/mnt/etc/nixos/hardware-configuration.nix"

# Replace UUID with partition labels for root and boot in configuration.nix
sed -i '/fileSystems\."\/"/s|/dev/disk/by-uuid/[^"]*|/dev/disk/by-label/NIXROOT|' "$CONFIG_PATH"
sed -i '/fileSystems\."\/boot"/s|/dev/disk/by-uuid/[^"]*|/dev/disk/by-label/NIXBOOT|' "$CONFIG_PATH"

# Remove git repo hardware repo
rm -rf /mnt/keranod/.dotfiles/hosts/$HOSTNAME/hardware-configuration.nix
cp $CONFIG_PATH /mnt/keranod/.dotfiles/hosts/$HOSTNAME

# Start the NixOS installation
echo "Starting NixOS installation..."
nixos-install --flake /mnt/home/keranod/.dotfiles#$HOSTNAME

echo "NixOS installation complete."

echo "Unmounting bootable ISO..."
umount --lazy /iso || umount --force /iso

# setup home-manager for keranod
nixos-enter --command "chown -R keranod /home/keranod/.dotfiles && sudo -u keranod home-manager switch --flake /home/keranod/.dotfiles#keranod && passwd --expire root && passwd --expire keranod"

reboot
