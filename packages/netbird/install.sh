#!/bin/bash
#
# NetBird Installation
#
# This script installs and configures NetBird for both GUI and headless systems.

set -e

# Determine if we should install the GUI or headless version
if [ "$1" == "--headless" ]; then
    echo "Installing NetBird (headless)..."
    yay -S --needed --noconfirm netbird
else
    echo "Installing NetBird (GUI)..."
    yay -S --needed --noconfirm netbird-ui
fi

# Create configuration directory
sudo mkdir -p /etc/netbird

# Create a basic configuration file to enable systemd logging
sudo tee /etc/netbird/config.json > /dev/null <<EOF
{
    "log_to_systemd": true
}
EOF

# Enable the NetBird service
echo "Enabling and starting NetBird service..."
sudo systemctl enable netbird
sudo systemctl start netbird

echo "NetBird installation complete."
