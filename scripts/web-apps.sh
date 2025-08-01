#!/bin/bash
# Manages web application launchers.

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# --- Web App Functions ---
web2app() {
  if [ "$#" -ne 3 ]; then
    echo "Usage: web2app <AppName> <AppURL> <IconURL>"
    return 1
  fi

  local APP_NAME="$1"
  local APP_URL="$2"
  local ICON_URL="$3"
  local ICON_DIR="$HOME/.local/share/icons/hicolor/48x48/apps"
  local DESKTOP_DIR="$HOME/.local/share/applications"
  local DESKTOP_FILE="$DESKTOP_DIR/${APP_NAME// /_}.desktop"
  local ICON_PATH="${ICON_DIR}/${APP_NAME// /_}.png"

  mkdir -p "$ICON_DIR"
  mkdir -p "$DESKTOP_DIR"

  if ! curl -sL -o "$ICON_PATH" "$ICON_URL"; then
    log_error "Failed to download icon."
    return 1
  fi

  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=$APP_NAME
Exec=chromium --new-window --ozone-platform=wayland --app="$APP_URL" --name="$APP_NAME" --class="$APP_NAME"
Terminal=false
Type=Application
Icon=$ICON_PATH
StartupNotify=true
EOF

  chmod +x "$DESKTOP_FILE"
  log_success "Web app '$APP_NAME' created."
  update-desktop-database "$DESKTOP_DIR"
}

web2app-remove() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: web2app-remove <AppName>"
    return 1
  fi

  local APP_NAME="$1"
  local ICON_DIR="$HOME/.local/share/icons/hicolor/48x48/apps"
  local DESKTOP_DIR="$HOME/.local/share/applications"
  local DESKTOP_FILE="$DESKTOP_DIR/${APP_NAME// /_}.desktop"
  local ICON_PATH="${ICON_DIR}/${APP_NAME// /_}.png"

  if [ -f "$DESKTOP_FILE" ]; then
    rm "$DESKTOP_FILE"
    rm "$ICON_PATH"
    log_success "Web app '$APP_NAME' removed."
    update-desktop-database "$DESKTOP_DIR"
  else
    log_error "Web app '$APP_NAME' not found."
  fi
}

# --- Main Logic ---
main_menu() {
    local choice
    choice=$(gum choose "Add a web app" "Remove a web app" "Exit")

    case "$choice" in
        "Add a web app")
            local name url icon
            name=$(gum input --placeholder "Application Name (e.g., Google Docs)")
            url=$(gum input --placeholder "Application URL (e.g., https://docs.google.com)")
            icon=$(gum input --placeholder "Icon URL (PNG format, e.g., from dashboardicons.com)")
            if [[ -n "$name" && -n "$url" && -n "$icon" ]]; then
                web2app "$name" "$url" "$icon"
            fi
            main_menu
            ;;
        "Remove a web app")
            local app_to_remove
            app_to_remove=$(find ~/.local/share/applications -name "*.desktop" -exec basename {} .desktop \; | gum filter --placeholder "Select a web app to remove")
            if [[ -n "$app_to_remove" ]]; then
                web2app-remove "$app_to_remove"
            fi
            main_menu
            ;;
        "Exit")
            exit 0
            ;;
    esac
}

main_menu
