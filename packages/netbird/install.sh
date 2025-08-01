#!/bin/bash
#
# NetBird Installation
#
# This script installs and configures NetBird.

set -e

# 1. General
# -----------------------------------------------------------------------------
echo "Installing NetBird..."

# Install NetBird
yay -S --needed --noconfirm netbird-ui

# Enable the NetBird service
sudo systemctl enable netbird
sudo systemctl start netbird
