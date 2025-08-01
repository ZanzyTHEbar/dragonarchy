#!/bin/bash
#
# Dragon Host-Specific Setup
#
# This script configures the Dragon workstation.

set -e

echo "Running setup for dragon..."

# Install GUI NetBird client
echo "Installing GUI NetBird client..."
bash "$HOME/dotfiles/packages/netbird/install.sh"

echo "Dragon setup complete."
