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


# Install and enable dynamic LED service
echo "Installing dynamic_led service..."
sudo install -D -m 0755 "$HOME/dotfiles/hosts/dragon/dynamic_led.py" /usr/local/bin/dynamic_led.py
sudo cp "$HOME/dotfiles/hosts/dragon/dynamic_led.service" /etc/systemd/system/dynamic_led.service
sudo systemctl daemon-reload
sudo systemctl enable --now dynamic_led.service


echo "Dragon setup complete."
