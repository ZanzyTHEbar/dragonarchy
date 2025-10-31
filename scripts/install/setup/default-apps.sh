#!/bin/bash
# Sets default applications for various file types (MIME types).

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1"; }

log_info "Setting default applications..."

log_info "Updating application database..."


DIR="$HOME/.local/share/applications"

if [[ ! -d "$DIR" ]]; then

    log_info "$DIR directory does not exist"
    log_info "Creating $DIR"
    mkdir -p $DIR

else
    log_info "$DIR exists, proceeding ..."
fi

sudo update-desktop-database $DIR

log_info "Setting default image viewer to 'imv'..."
xdg-mime default imv.desktop image/png
xdg-mime default imv.desktop image/jpeg
xdg-mime default imv.desktop image/gif
xdg-mime default imv.desktop image/webp
xdg-mime default imv.desktop image/bmp
xdg-mime default imv.desktop image/tiff

log_info "Setting default PDF viewer to 'Evince'..."
xdg-mime default org.gnome.Evince.desktop application/pdf

# Set default web browser
# Try to detect installed browsers, preferring vivaldi, then firefox, then chromium
BROWSER_DESKTOP=""
if command -v vivaldi >/dev/null 2>&1; then
    BROWSER_DESKTOP="vivaldi-stable.desktop"
elif command -v firefox >/dev/null 2>&1; then
    BROWSER_DESKTOP="firefox.desktop"
elif command -v chromium >/dev/null 2>&1; then
    BROWSER_DESKTOP="chromium.desktop"
fi

if [ -n "$BROWSER_DESKTOP" ]; then
    log_info "Setting default web browser to '$BROWSER_DESKTOP'..."
    # Only set if $BROWSER env var is not set (which prevents xdg-settings from working)
    if [ -z "$BROWSER" ]; then
        xdg-settings set default-web-browser "$BROWSER_DESKTOP" 2>/dev/null || log_info "Could not set default web browser via xdg-settings (may require manual setup)"
    else
        log_info "Skipping browser setting: \$BROWSER is set to '$BROWSER', which prevents xdg-settings from working"
    fi
    # Set MIME types regardless of $BROWSER env var
    xdg-mime default "$BROWSER_DESKTOP" x-scheme-handler/http 2>/dev/null || true
    xdg-mime default "$BROWSER_DESKTOP" x-scheme-handler/https 2>/dev/null || true
else
    log_info "No supported browser found (vivaldi/firefox/chromium). Skipping browser default setup."
fi

log_info "Setting default video player to 'mpv'..."
xdg-mime default mpv.desktop video/mp4 video/x-msvideo video/x-matroska video/x-flv video/x-ms-wmv video/mpeg video/ogg video/webm video/quicktime video/3gpp video/3gpp2 video/x-ms-asf video/x-ogm+ogg video/x-theora+ogg application/ogg

log_info "Default application setup complete."
