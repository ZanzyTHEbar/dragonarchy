#!/bin/bash
#
# NetBird Installation
#
# This script installs and configures NetBird for both GUI and headless systems.

set -e

# Check if NetBird is already installed to make the script idempotent.
if command -v netbird &> /dev/null; then
    echo "NetBird is already installed. Skipping core installation."
else
    echo "Installing NetBird using the official script..."
    # Create a temporary directory to run the installer in, to avoid conflicts
    # with existing directories. The official script clones a 'netbird' git repo.
    INSTALL_DIR=$(mktemp -d)
    (
        cd "$INSTALL_DIR" || exit 1
        # The official script adds the repository and installs the 'netbird' package.
        curl -fsSL https://pkgs.netbird.io/install.sh | sh
    )
    # Clean up the temporary directory
    rm -rf "$INSTALL_DIR"
fi

# Now that the package is installed, we need to ensure the service is running.
echo "Ensuring the NetBird service is enabled and running..."
sudo systemctl enable --now netbird

# If we are not on a headless system, install the GUI client.
if [ "$1" != "--headless" ]; then
    echo "Installing NetBird GUI..."
    # The GUI is a separate package and needs to be installed via AUR.
    yay -S --needed --noconfirm netbird-ui
fi

echo "NetBird installation complete."
echo
echo "IMPORTANT: To connect this machine to your network, run: netbird up"
echo "You will be prompted to log in via your browser to authorize the new peer."
