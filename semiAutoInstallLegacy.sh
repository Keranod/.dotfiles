#!/bin/bash

# Ensure a disk name is provided
if [ -z "$1" ]; then
  echo "Specify disk to install on"
  echo "Check which one using 'lsblk'"
  echo "eg., /dev/sda or /dev/nvme0n1"
  exit 1
fi

DISK="$1"

# Determine partition suffix (p1/p2 for disks ending in a number)
if [[ "$DISK" =~ [0-9]$ ]]; then
  PART1="${DISK}p1"
  PART2="${DISK}p2"
else
  PART1="${DISK}1"
  PART2="${DISK}2"
fi

# Ensure a hostname is provided
if [ -z "$2" ]; then
  echo "Specify the hostname (machine name)"
  exit 1
fi

HOSTNAME="$2"

# Wipe the disk (destroy all existing partitions)
echo "Wiping disk $DISK..."
wipefs --all --force "$DISK"

# Legacy Partitioning (MBR)
echo "Partitioning $DISK (Legacy)..."
parted $DISK -- mklabel msdos
parted $DISK -- mkpart primary ext4 1MiB 100%

# Verify partitions exist
if [ ! -b "$PART1" ]; then
  echo "Partition $PART1 does not exist. Exiting."
  exit 1
fi

echo "Formatting and labeling partitions..."
mkfs.ext4 "$PART1" -L NIXROOT

# Wait for commands to finish
sync
sleep 1  # Wait a second for the formatting to be fully registered
lsblk -o name,mountpoint,label,size,uuid
# Reread partition table
blockdev --rereadpt $DISK

# Wait to ensure the partition table is reread
sleep 1

# Mount partitions
echo "Mounting partitions..."
mount /dev/disk/by-label/NIXROOT /mnt

# Check if /mnt is mounted successfully
if mount | grep -q "/mnt"; then
  echo "Root partition mounted successfully."
else
  echo "Failed to mount root partition."
  exit 1
fi

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
echo "Generating NixOS configuration..."
nixos-generate-config --root /mnt

CONFIG_PATH="/mnt/etc/nixos/hardware-configuration.nix"
TARGET_PATH="/mnt/home/keranod/.dotfiles/hosts/$HOSTNAME/hardware-configuration.nix"

# Skip copying if the file already exists
if [ -f "$TARGET_PATH" ]; then
    echo "Hardware configuration already exists at $TARGET_PATH. Skipping copy..."
else
    echo "Copying hardware configuration..."
    rm -f "$TARGET_PATH"
    cp "$CONFIG_PATH" "$TARGET_PATH"
fi

# Git commit to not cause errors during install
cd /mnt/home/keranod/.dotfiles
git add .
git commit -c user.name="Keranod" -c user.email="konrad.konkel@wp.pl" -m "Pre-install commit"

# Start the NixOS installation
echo "Starting NixOS installation..."
nixos-install --flake /mnt/home/keranod/.dotfiles#$HOSTNAME

echo "NixOS installation complete."

# Unmount bootable ISO
umount --lazy /iso || umount --force /iso

# Setup home-manager for keranod
nixos-enter --command "chown -R keranod /home/keranod/.dotfiles && passwd --expire root && passwd --expire keranod"

echo "Rebooting in 60 seconds..."
sleep 60
reboot
