#!/bin/bash
# Refreshes application icons and desktop files.

# Copy and sync icon files
mkdir -p ~/.local/share/icons/hicolor/48x48/apps/
cp -f "$(dirname "$0")/../../packages/applications/.local/share/icons/hicolor/48x48/apps/"*.png ~/.local/share/icons/hicolor/48x48/apps/
gtk-update-icon-cache ~/.local/share/icons/hicolor &>/dev/null

# Copy .desktop declarations
mkdir -p ~/.local/share/applications
cp -f "$(dirname "$0")/../../packages/applications/.local/share/applications/"*.desktop ~/.local/share/applications/
cp -f "$(dirname "$0")/../../packages/applications/.local/share/applications/hidden/"*.desktop ~/.local/share/applications/

update-desktop-database ~/.local/share/applications
