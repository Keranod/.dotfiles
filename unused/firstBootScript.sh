#!/bin/bash

FLAGPATH="/home/root/firstBootScript.flag"

# Check if the temp file exists. If it does, exit to prevent re-running the script.
if [ -f $FLAGPATH ]; then
  echo "Script already completed. Exiting..."
  # Delete service and flag file
  systemctl stop firstBootScript.service
  systemctl disable firstBootScript.service
  exit 0
fi

# Run the necessary commands
echo "Changing root password..."
passwd root

echo "Changing user password..."
passwd keranod

echo "Running home-manager..."
sudo -u keranod home-manager switch --flake /home/keranod/.dotfiles#keranod

# Mark script as completed by creating a flag file
touch $FLAGPATH
chmod 444 $FLAGPATH

echo "Pre-GUI setup completed."

# reboot
