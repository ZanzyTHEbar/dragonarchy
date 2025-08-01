#!/bin/bash
#
# NetBird Installation
#
# This script installs and configures NetBird for both GUI and headless systems.

set -e

echo "Installing NetBird using the official script..."
# The official script adds the repository and installs the 'netbird' package.
curl -fsSL https://pkgs.netbird.io/install.sh | sh

# Now that the package is installed, we need to ensure the service is running.
echo "Enabling and starting NetBird service..."
sudo systemctl enable --now netbird

# The 'netbird up' command is interactive and should be run by the user manually
# after the installation script completes.

# If we are not on a headless system, install the GUI client.
if [ "$1" != "--headless" ]; then
    echo "Installing NetBird GUI..."
    # The GUI is a separate package and needs to be installed via AUR.
    yay -S --needed --noconfirm netbird-ui
fi

echo "NetBird installation complete."
echo
echo "IMPORTANT: Please run 'netbird up' to connect this machine to your network."
echo "You will be prompted to log in via your browser to authorize the new peer."
