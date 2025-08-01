#!/usr/bin/env zsh

set -euo pipefail

THEME_NAME=$1

# Set the cursor theme for GTK applications
gsettings set org.gnome.desktop.interface cursor-theme "$THEME_NAME"

# Set the cursor theme for the environment
if ! grep -q "XCURSOR_THEME" "$HOME/.config/environment.d/10-cursor.conf" 2>/dev/null; then
    echo "XCURSOR_THEME=$THEME_NAME" | sudo tee -a "$HOME/.config/environment.d/10-cursor.conf" > /dev/null
else
    sudo sed -i "s/XCURSOR_THEME=.*/XCURSOR_THEME=$THEME_NAME/" "$HOME/.config/environment.d/10-cursor.conf"
fi

echo "Cursor theme set to $THEME_NAME"
