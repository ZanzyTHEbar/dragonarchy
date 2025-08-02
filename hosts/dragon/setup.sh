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

echo "Dragon setup complete."
