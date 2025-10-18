#!/bin/bash

# --- Positional args with “fail if missing” ---
DISK="${1:?Error: you must specify a disk (eg. /dev/sda)}"; DISK="${DISK,,}"
HOSTNAME="${2:?Error: you must specify a hostname}"
USERNAME="${3:?Error: you must specify a username}"; USERNAME="${USERNAME,,}"
EMAIL="${4:?Error: you must specify an email}"; EMAIL="${EMAIL,,}"
PROXY="${5:-}"; PROXY="${PROXY,,}"

echo "Disk:     $DISK"
echo "Host:     $HOSTNAME"
echo "User:     $USERNAME"
echo "Email:    $EMAIL"
echo "Proxy:    ${PROXY:-<none>}"

# Determine partition suffix (p1/p2 for disks ending in a number)
if [[ "$DISK" =~ [0-9]$ ]]; then
  PART1="${DISK}p1"
  PART2="${DISK}p2"
else
  PART1="${DISK}1"
  PART2="${DISK}2"
fi

# Check if a proxy is provided
if [ -n "$PROXY" ]; then
  echo "Setting proxy to $PROXY"

  # Set proxy for curl (for downloading or installing)
  export http_proxy="$PROXY"
  export https_proxy="$PROXY"

  # Temporarily set Git proxy if it's not installed yet
  git_proxy="http.proxy"
  git config --global $git_proxy "$PROXY"
else
  echo "No proxy specified, proceeding without setting proxy"
fi

# Install Git if it's not already installed (example for NixOS with nix-shell)
nix-shell -p git

# After Git is installed, configure the proxy for Git if necessary
if [ -n "$PROXY" ]; then
  git config --global http.proxy "$PROXY"
  git config --global https.proxy "$PROXY"
fi

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

# ----------------------------------------------------
# PARTITIONING
# ----------------------------------------------------

if [ "$IS_UEFI" == "true" ]; then
  echo "Partitioning $DISK for UEFI (GPT)..."
  parted $DISK -- mklabel gpt
  parted $DISK -- mkpart ESP fat32 1MiB 512MiB # PART1: /boot
  parted $DISK -- set 1 esp on
  # PART2: The main partition for LUKS (no filesystem type specified here)
  parted $DISK -- mkpart primary 512MiB 100% 
else
  echo "Partitioning $DISK for Legacy (MBR)..."
  parted $DISK -- mklabel msdos
  parted $DISK -- mkpart primary ext4 1MiB 500MiB # PART1: /boot
  # PART2: The main partition for LUKS (no filesystem type specified here)
  parted $DISK -- mkpart primary 500MiB 100%
fi

# Verify partitions exist
if [ ! -b "$PART1" ] || [ ! -b "$PART2" ]; then
  echo "Partitions $PART1 or $PART2 do not exist. Exiting."
  exit 1
fi

# ----------------------------------------------------
# FORMATTING AND ENCRYPTION (CRITICAL CHANGES HERE)
# ----------------------------------------------------

echo "Formatting and ENCRYPTING partitions..."

# Format /boot
mkfs.fat -F 32 "$PART1"
fatlabel "$PART1" NIXBOOT

# Apply LUKS encryption to the main partition
echo -e "\n\n!!! STARTING LUKS FORMAT. ENTER PASSPHRASE NOW (will wait indefinitely) !!!\n\n"
# CRITICAL FIX: Use </dev/tty to force interactive, indefinite wait
cryptsetup luksFormat "$PART2" --label NIXROOT_CRYPT </dev/tty

echo -e "\n\n!!! LUKS FORMAT COMPLETE. ENTER PASSPHRASE TO UNLOCK (will wait indefinitely) !!!\n\n"
# CRITICAL FIX: Use </dev/tty to force interactive, indefinite wait
cryptsetup luksOpen "$PART2" NIXROOT </dev/tty

# Format the unlocked volume
mkfs.ext4 /dev/mapper/NIXROOT -L NIXROOT_FS

# Wait for commands to finish
sync
sleep 1
lsblk -o name,mountpoint,label,size,uuid
blockdev --rereadpt $DISK
sleep 1

# ----------------------------------------------------
# MOUNTING (Use the decrypted device)
# ----------------------------------------------------
echo "Mounting partitions..."
# Mount the decrypted volume as root
mount /dev/mapper/NIXROOT /mnt 
mkdir -p /mnt/boot
mount "$PART1" /mnt/boot # Mount /boot partition

# Check if both /mnt and /mnt/boot are mounted successfully
if mount | grep -q "/mnt" && mount | grep -q "/mnt/boot"; then
  echo "Both root and EFI partitions mounted successfully."
else
  echo "Failed to mount root or EFI partition."
  exit 1
fi

echo "Partitioning, encryption, and mounting complete."

# ----------------------------------------------------
# SWAP (Inside the encrypted volume)
# ----------------------------------------------------
echo "Creating swap file INSIDE the encrypted volume"
dd if=/dev/zero of=/mnt/.swapfile bs=1M count=2048 # 2GB size
chmod 600 /mnt/.swapfile
mkswap /mnt/.swapfile
swapon /mnt/.swapfile

# ----------------------------------------------------
# CONFIG GENERATION
# ----------------------------------------------------
# Generate configuration after LUKS device is opened and mounted
# Check if configuration.nix exists for the hostname
if [ ! -f "/mnt/home/$USERNAME/.dotfiles/hosts/$HOSTNAME/configuration.nix" ]; then
  echo "Error: configuration.nix not found for '$HOSTNAME'"
  exit 1
fi

# Generate configuration for NixOS
echo "Generating NixOS configuration..."
nixos-generate-config --root /mnt

# Install git and clone dotfiles
echo "Installing git and cloning dotfiles..."
nix-shell -p git && mkdir -p /mnt/home/$USERNAME && git clone https://github.com/keranod/.dotfiles /mnt/home/$USERNAME/.dotfiles && cd /mnt/home/$USERNAME/.dotfiles && git remote set-url origin git@github.com:Keranod/.dotfiles.git && git remote -v

# Check if the hostname folder exists
if [ ! -d "/mnt/home/$USERNAME/.dotfiles/hosts/$HOSTNAME" ]; then
  echo "Error: Host configuration for '$HOSTNAME' not found in .dotfiles/hosts/"
  exit 1
fi

CONFIG_PATH="/mnt/etc/nixos/hardware-configuration.nix"
TARGET_PATH="/mnt/home/$USERNAME/.dotfiles/hosts/$HOSTNAME/hardware-configuration.nix"

# Skip copying if the file already exists
if [ -f "$TARGET_PATH" ]; then
    echo "Hardware configuration already exists at $TARGET_PATH. Skipping copy..."
else
    echo "Copying hardware configuration..."
    rm -f "$TARGET_PATH"
    cp "$CONFIG_PATH" "$TARGET_PATH"
fi

# Git commit to not cause errors during install
cd /mnt/home/$USERNAME/.dotfiles
git add .
git -c user.name="$USERNAME" -c user.email="$EMAIL" commit -m "Pre-install commit"

# Start the NixOS installation
echo "Starting NixOS installation..."
nixos-install --flake /mnt/home/$USERNAME/.dotfiles#$HOSTNAME

echo "NixOS installation complete."

echo "Creating SSH Key"
mkdir -p "/mnt/home/$USERNAME/.dotfiles/.ssh"
ssh-keygen -t ed25519 -C "$EMAIL" -f "/mnt/home/$USERNAME/.dotfiles/.ssh/id_ed25519" -N ""
cp /mnt/home/$USERNAME/.dotfiles/.ssh/id_ed25519.pub /mnt/home/$USERNAME/.dotfiles/hosts/$HOSTNAME

# Git commit ssh keys
cd /mnt/home/$USERNAME/.dotfiles
git add .
git -c user.name="$USERNAME" -c user.email="$EMAIL" commit -m "Git ssh key commit"

# echo "Unmounting bootable ISO..."
# umount --lazy /iso || umount --force /iso

# setup home-manager for user
nixos-enter --command "chown -R $USERNAME /home/$USERNAME/.dotfiles && passwd --expire root && passwd --expire $USERNAME"

echo "Rebooting in 60 seconds..."
sleep 60
reboot
