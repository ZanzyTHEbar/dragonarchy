#!/bin/bash
#
# Golden Dragon Host-Specific Setup
#
# This script configures the Golden Dragon workstation.

set -e

echo "Running setup for goldendragon..."

# Install NetBird
echo "Installing NetBird ..."
bash "$HOME/dotfiles/scripts/utilities/netbird-install.sh"

# Configure remote LUKS unlock
if gum confirm "Configure remote LUKS unlock for this machine?"; then
    echo "Configuring remote LUKS unlock..."
    sudo "$HOME/dotfiles/scripts/utilities/dropbear-luks-unlock.sh"
fi

echo "Golden Dragon setup complete."
