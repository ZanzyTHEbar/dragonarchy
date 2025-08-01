#!/usr/bin/env zsh

set -euo pipefail

# Configuration
THEME_NAME="Bibata-Modern-Classic"
THEME_DIR="$HOME/.local/share/icons"
DOWNLOAD_URL="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz"

# Function to log messages
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

# Ensure the target directory exists
mkdir -p "$THEME_DIR"

# Download and extract the cursor theme
log_info "Downloading Bibata cursor theme..."
TMP_DIR=$(mktemp -d)
curl -L "$DOWNLOAD_URL" | tar -xJ -C "$TMP_DIR"
mv "$TMP_DIR/$THEME_NAME" "$THEME_DIR/"
rm -rf "$TMP_DIR"

# Set the cursor theme
log_info "Setting GSettings for cursor theme..."
gsettings set org.gnome.desktop.interface cursor-theme "$THEME_NAME"

# Set environment variable for Wayland/X11
log_info "Updating environment configuration for cursor theme..."
if ! grep -q "XCURSOR_THEME" "$HOME/.config/environment.d/10-cursor.conf"; then
    echo "XCURSOR_THEME=$THEME_NAME" | sudo tee -a "$HOME/.config/environment.d/10-cursor.conf"
fi

# Clean up old cursor themes if they exist
find "$THEME_DIR" -mindepth 1 -maxdepth 1 ! -name "$THEME_NAME" -exec rm -rf {} +

echo "Cursor theme set to $THEME_NAME."
