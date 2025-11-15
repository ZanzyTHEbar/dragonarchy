#!/usr/bin/env bash
# Setup script for clipboard system
# Creates symlinks for clipboard scripts

set -euo pipefail

echo "Setting up clipboard system..."

# Create symlinks in ~/.local/bin
cd ~/.local/bin

# Remove old symlinks if they exist
rm -f clipse-wrapper clipboard-menu generate-clipse-themes test-clipse-theme walker-clipboard

# Create new relative symlinks
ln -sf ../../dotfiles/packages/hyprland/.local/bin/clipse-wrapper .
ln -sf ../../dotfiles/packages/hyprland/.local/bin/clipboard-menu .
ln -sf ../../dotfiles/packages/hyprland/.local/bin/generate-clipse-themes .
ln -sf ../../dotfiles/packages/hyprland/.local/bin/test-clipse-theme .
ln -sf ../../dotfiles/packages/hyprland/.local/bin/walker-clipboard .

echo "✅ Symlinks created:"
ls -lh clipse-wrapper clipboard-menu generate-clipse-themes test-clipse-theme walker-clipboard

# Ensure clipse daemon is running
if ! pgrep -x clipse >/dev/null; then
    echo "Starting clipse daemon..."
    clipse -listen &
    sleep 0.5
fi

# Generate themes
if command -v generate-clipse-themes >/dev/null; then
    echo "Generating clipse themes..."
    generate-clipse-themes
fi

echo ""
echo "✅ Clipboard system ready!"
echo ""
echo "Keybindings:"
echo "  Super + V       - Quick clipboard (clipse)"
echo "  Alt + V         - Advanced clipboard (Walker)"
echo "  Super + Alt + V - Clipboard menu"


