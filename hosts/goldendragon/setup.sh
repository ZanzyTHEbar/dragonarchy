#!/bin/bash
#
# GoldenDragon Host-Specific Setup
#
# This script configures the GoldenDragon workstation.

set -e

echo "Running setup for GoldenDragon..."

# Install NetBird
echo "Installing NetBird ..."
bash "$HOME/dotfiles/scripts/utilities/netbird-install.sh"

# Copy host-specific system configs
echo "Copying host-specific system configs..."
sudo cp -rT "$HOME/dotfiles/hosts/goldendragon/etc/" /etc/

# Apply DNS changes
echo "Restarting systemd-resolved to apply DNS changes..."
sudo systemctl restart systemd-resolved


echo "GoldenDragon setup complete."
