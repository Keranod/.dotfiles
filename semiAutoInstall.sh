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

# Check if EFI variables are supported
if efibootmgr 2>&1 | grep -q "EFI variables are not supported"; then
  IS_UEFI="false"
else
  IS_UEFI="true"
fi

echo "UEFI mode: $IS_UEFI"

# Wipe the disk (destroy all existing partitions)
echo "Wiping disk $DISK..."
wipefs --all --force "$DISK"
# parted --script $DISK mklabel gpt

if [ "$IS_UEFI" == "true" ]; then
  echo "Partitioning $DISK for UEFI (GPT)..."
  parted $DISK -- mklabel gpt
  parted $DISK -- mkpart ESP fat32 1MiB 512MiB
  parted $DISK -- set 1 esp on
  parted $DISK -- mkpart primary ext4 512MiB 100%
else
echo "Partitioning $DISK for Legacy (MBR)..."
parted $DISK -- mklabel msdos
parted $DISK -- mkpart primary ext4 1MiB 500MiB
parted $DISK -- mkpart primary ext4 500MiB 100%
fi

# Verify partitions exist
if [ ! -b "$PART1" ] || [ ! -b "$PART2" ]; then
  echo "Partitions $PART1 or $PART2 do not exist. Exiting."
  exit 1
fi

echo "Formatting and labeling partitions..."
mkfs.fat -F 32 "$PART1"
fatlabel "$PART1" NIXBOOT
mkfs.ext4 "$PART2" -L NIXROOT

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
nix-shell -p git && mkdir -p /mnt/home/keranod && git clone https://github.com/keranod/.dotfiles /mnt/home/keranod/.dotfiles && cd /mnt/home/keranod/.dotfiles && git remote set-url origin git@github.com:Keranod/.dotfiles.git && git remote -v

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

email="konrad.konkel@wp.pl"

# Git commit to not cause errors during install
cd /mnt/home/keranod/.dotfiles
git add .
git -c user.name="Keranod" -c user.email="$email" commit -m "Pre-install commit"

# Start the NixOS installation
echo "Starting NixOS installation..."
nixos-install --flake /mnt/home/keranod/.dotfiles#$HOSTNAME

echo "NixOS installation complete."

echo "Creating SSH Key"
mkdir -p "/mnt/home/keranod/.dotfiles/.ssh"
ssh-keygen -t rsa -b 4096 -C "$email" -f "/mnt/home/keranod/.dotfiles/.ssh/id_rsa" -N ""
cp /mnt/home/keranod/.dotfiles/.shh/id_rsa.pub /mnt/home/keranod/.dotfiles/hosts/$HOSTNAME

# Git commit ssh keys
cd /mnt/home/keranod/.dotfiles
git add .
git -c user.name="Keranod" -c user.email="$email" commit -m "Git ssh key commit"

# echo "Unmounting bootable ISO..."
# umount --lazy /iso || umount --force /iso

# setup home-manager for keranod
nixos-enter --command "chown -R keranod /home/keranod/.dotfiles && passwd --expire root && passwd --expire keranod"

echo "Rebooting in 60 seconds..."
sleep 60
reboot
