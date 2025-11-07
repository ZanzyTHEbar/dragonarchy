#!/bin/bash
# Load Hyprland gesture plugins

PLUGIN_DIR="$HOME/.local/share/hyprland-plugins"

# Load hyprgrass plugin
if [[ -f "$PLUGIN_DIR/hyprgrass/build/hyprgrass.so" ]]; then
    hyprctl plugin load "$PLUGIN_DIR/hyprgrass/build/hyprgrass.so"
fi
