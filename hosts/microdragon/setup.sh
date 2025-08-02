#!/bin/bash
#
# Microdragon Host-Specific Setup
#
# This script configures the Raspberry Pi as a NetBird routing peer.

set -e

echo "Running setup for microdragon..."

# Install NetBird
echo "Installing NetBird ..."
bash "$HOME/dotfiles/scripts/utilities/netbird-install.sh"

# Enable IP forwarding
echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-netbird.conf

echo "Microdragon setup complete."
