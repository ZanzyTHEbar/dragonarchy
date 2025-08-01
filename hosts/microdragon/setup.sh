#!/bin/bash
#
# Microdragon Host-Specific Setup
#
# This script configures the Raspberry Pi as a NetBird routing peer.

set -e

echo "Running setup for microdragon..."

# Install headless NetBird client
echo "Installing headless NetBird client..."
bash "$HOME/dotfiles/packages/netbird/install.sh" --headless

# Enable IP forwarding
echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-netbird.conf

echo "Microdragon setup complete."
