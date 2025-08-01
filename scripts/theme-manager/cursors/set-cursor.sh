#!/usr/bin/env zsh

set -euo pipefail

if [[ -z "$1" ]]; then
    echo "Usage: $0 <theme_name>"
    exit 1
fi

THEME_NAME=$1
HYPRLAND_ENV_CONFIG="$HOME/.config/hypr/config/environment.conf"
CURSOR_SIZE=22

# Helper function to update environment variables in Hyprland config
update_hypr_env_var() {
    local var_name="$1"
    local var_value="$2"
    local config_file="$3"

    # Check if the variable exists and update it, otherwise add it
    if grep -q "^env = $var_name," "$config_file"; then
        sed -i "s/^env = $var_name,.*/env = $var_name,$var_value/" "$config_file"
    else
        echo "env = $var_name,$var_value" >> "$config_file"
    fi
}

# 1. Persist theme in Hyprland's environment config for both hyprcursor and xcursor
update_hypr_env_var "HYPRCURSOR_THEME" "$THEME_NAME" "$HYPRLAND_ENV_CONFIG"
update_hypr_env_var "XCURSOR_THEME" "$THEME_NAME" "$HYPRLAND_ENV_CONFIG"
update_hypr_env_var "HYPRCURSOR_SIZE" "$CURSOR_SIZE" "$HYPRLAND_ENV_CONFIG"
update_hypr_env_var "XCURSOR_SIZE" "$CURSOR_SIZE" "$HYPRLAND_ENV_CONFIG"

# 2. Set GTK cursor theme
gsettings set org.gnome.desktop.interface cursor-theme "$THEME_NAME"

# 3. Apply the cursor theme to the running Hyprland session
hyprctl setcursor "$THEME_NAME" "$CURSOR_SIZE"

echo "Cursor theme set to $THEME_NAME."
echo "NOTE: For Flatpak applications, you may need to run the following command once:"
echo "flatpak override --filesystem=~/.icons:ro --user"
