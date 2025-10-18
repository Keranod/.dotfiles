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

# --- Proxy setup (omitted for brevity) ---

# Check if EFI variables are supported
if efibootmgr 2>&1 | grep -q "EFI variables are not supported"; then
  IS_UEFI="false"
else
  IS_UEFI="true"
fi

# Check for TPM device (TPM2)
if [ -c /dev/tpmrm0 ]; then
  IS_TPM="true"
else
  IS_TPM="false"
fi

# Conditional Check
if [ "$IS_UEFI" == "true" ] && [ "$IS_TPM" == "true" ]; then
  IS_ENCRYPTED="true"
  echo ">>> CONDITION MET: UEFI ($IS_UEFI) and TPM ($IS_TPM) detected. Enabling LUKS/TPM encryption."
else
  IS_ENCRYPTED="false"
  echo ">>> CONDITION NOT MET: UEFI ($IS_UEFI) or TPM ($IS_TPM) not detected. Performing unencrypted install."
fi

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
  parted $DISK -- mkpart primary 512MiB 100% # PART2: Root (encrypted or unencrypted)
else
  echo "Partitioning $DISK for Legacy (MBR)..."
  parted $DISK -- mklabel msdos
  parted $DISK -- mkpart primary ext4 1MiB 500MiB # PART1: /boot
  parted $DISK -- mkpart primary 500MiB 100% # PART2: Root (encrypted or unencrypted)
fi

# Verify partitions exist
if [ ! -b "$PART1" ] || [ ! -b "$PART2" ]; then
  echo "Partitions $PART1 or $PART2 do not exist. Exiting."
  exit 1
fi

# ----------------------------------------------------
# FORMATTING, ENCRYPTION, AND MOUNTING
# ----------------------------------------------------

# Format /boot (Unencrypted, required for all)
mkfs.fat -F 32 "$PART1"
fatlabel "$PART1" NIXBOOT

if [ "$IS_ENCRYPTED" == "true" ]; then
  echo "Applying LUKS encryption to $PART2..."
  
  # CRITICAL FIX: Use </dev/tty to force interactive, indefinite wait
  echo -e "\n\n!!! STARTING LUKS FORMAT. ENTER MANUAL PASSPHRASE NOW (will wait indefinitely) !!!\n\n"
  cryptsetup luksFormat "$PART2" --label NIXROOT_CRYPT </dev/tty

  echo -e "\n\n!!! LUKS FORMAT COMPLETE. ENTER PASSPHRASE TO UNLOCK (will wait indefinitely) !!!\n\n"
  cryptsetup luksOpen "$PART2" NIXROOT </dev/tty

  # Get the UUID of the physical partition for the post-install seal command
  # This is the UUID of the LUKS container, NOT the mapped device.
  ENCRYPTED_UUID=$(blkid -s UUID -o value "$PART2")
  
  # Format the unlocked volume
  mkfs.ext4 /dev/mapper/NIXROOT -L NIXROOT_FS

  # Mount the decrypted volume as root
  mount /dev/mapper/NIXROOT /mnt
else
  echo "Formatting $PART2 as standard ext4 (unencrypted)..."
  mkfs.ext4 "$PART2" -L NIXROOT_FS
  
  # Mount the unencrypted volume as root
  mount "$PART2" /mnt
fi

mkdir -p /mnt/boot
mount "$PART1" /mnt/boot # Mount /boot partition

# Check mounts
if mount | grep -q "/mnt" && mount | grep -q "/mnt/boot"; then
  echo "Both root and /boot partitions mounted successfully."
else
  echo "Failed to mount root or /boot partition."
  exit 1
fi

# ----------------------------------------------------
# SWAP (Inside the root volume)
# ----------------------------------------------------
echo "Creating swap file INSIDE the root volume"
dd if=/dev/zero of=/mnt/.swapfile bs=1M count=2048 # 2GB size
chmod 600 /mnt/.swapfile
mkswap /mnt/.swapfile
swapon /mnt/.swapfile

# ----------------------------------------------------
# CONFIG GENERATION AND INSTALL
# ----------------------------------------------------

# Generate configuration (this populates /mnt/etc/nixos/hardware-configuration.nix)
echo "Generating NixOS configuration (will detect LUKS setup if applicable)..."
nixos-generate-config --root /mnt

# Install git and clone dotfiles (Omitted for brevity, assuming this works)

# Check if configuration.nix exists for the hostname
if [ ! -f "/mnt/home/$USERNAME/.dotfiles/hosts/$HOSTNAME/configuration.nix" ]; then
  echo "Error: configuration.nix not found for '$HOSTNAME'"
  exit 1
fi

# Check if the hostname folder exists
if [ ! -d "/mnt/home/$USERNAME/.dotfiles/hosts/$HOSTNAME" ]; then
  echo "Error: Host configuration for '$HOSTNAME' not found in .dotfiles/hosts/"
  exit 1
fi

CONFIG_PATH="/mnt/etc/nixos/hardware-configuration.nix"
TARGET_PATH="/mnt/home/$USERNAME/.dotfiles/hosts/$HOSTNAME/hardware-configuration.nix"

# Copy hardware configuration into the flake structure
if [ -f "$TARGET_PATH" ]; then
    echo "Hardware configuration already exists at $TARGET_PATH. Skipping copy..."
else
    echo "Copying hardware configuration..."
    rm -f "$TARGET_PATH"
    cp "$CONFIG_PATH" "$TARGET_PATH"
fi

# Git commit (Omitted for brevity)

# Start the NixOS installation
echo "Starting NixOS installation..."

INSTALL_CMD="nixos-install --flake /mnt/home/$USERNAME/.dotfiles#$HOSTNAME"

if [ "$IS_ENCRYPTED" == "true" ]; then
    # Create the sealing command dynamically using the captured UUID
    SEAL_COMMAND='${pkgs.tpm2-luks}/bin/tpm2-luks-seal --device /dev/disk/by-uuid/'"${ENCRYPTED_UUID}"' --slot 1'
    
    echo "Adding TPM sealing to post-install hook..."
    echo "NOTE: You MUST enter the LUKS passphrase again for sealing."
    
    # IMPORTANT: The --post-install hook runs the SEAL_COMMAND inside the new system,
    # prompting the user for the passphrase to seal the key.
    $INSTALL_CMD --post-install "$SEAL_COMMAND"
else
    $INSTALL_CMD
fi

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
