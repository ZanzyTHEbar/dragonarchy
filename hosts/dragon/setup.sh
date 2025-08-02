#!/bin/bash
#
# Dragon Host-Specific Setup
#
# This script configures the Dragon workstation.

set -e

echo "Running setup for dragon..."

# Install NetBird
echo "Installing NetBird ..."
bash "$HOME/dotfiles/scripts/utilities/netbird-install.sh"

# Copy host-specific system configs
echo "Copying host-specific system configs..."
sudo cp -rT "$HOME/dotfiles/hosts/dragon/etc/" /etc/

# Apply DNS changes
echo "Restarting systemd-resolved to apply DNS changes..."
sudo systemctl restart systemd-resolved


echo "Dragon setup complete."
