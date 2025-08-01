#!/bin/bash
#
# Golden Dragon Host-Specific Setup
#
# This script configures the Golden Dragon workstation.

set -e

echo "Running setup for goldendragon..."

# Install GUI NetBird client
echo "Installing GUI NetBird client..."
bash "$HOME/dotfiles/packages/netbird/install.sh"

echo "Golden Dragon setup complete."
