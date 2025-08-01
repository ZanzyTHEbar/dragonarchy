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
        # NOTE! As of 0.52.1 The install script is not working, so we need to install the package manually.
        # curl -fsSL https://pkgs.netbird.io/install.sh | sh
        
        git clone https://aur.archlinux.org/netbird.git
        cd netbird

        # Checkout the correct version
        git checkout 3f463ca9af98b620a652639e1a16cb83b3df3127

        # Install the package
        makepkg -si

        # Check that the package is installed with the correct version 0.51.2
        if ! command -v netbird &> /dev/null; then
            echo "NetBird is not installed. Please check the installation."
            exit 1
        fi
        if ! netbird version | grep -q "0.51.2"; then
            echo "NetBird is not installed with the correct version. Please check the installation."
            exit 1
        fi

    )
    # Clean up the temporary directory
    rm -rf "$INSTALL_DIR"
fi

# Now that the package is installed, we need to ensure the service is running.
echo "Ensuring the NetBird service is enabled and running..."

sudo netbird service install
sudo netbird service start

sudo systemctl enable netbird

echo "NetBird installation complete."
echo
echo "IMPORTANT: To connect this machine to your network, run: netbird up"
echo "You will be prompted to log in via your browser to authorize the new peer."
