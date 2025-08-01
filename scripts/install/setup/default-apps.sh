#!/bin/bash
# Sets default applications for various file types (MIME types).

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1"; }

log_info "Setting default applications..."

log_info "Updating application database..."
update-desktop-database ~/.local/share/applications

log_info "Setting default image viewer to 'imv'..."
xdg-mime default imv.desktop image/png
xdg-mime default imv.desktop image/jpeg
xdg-mime default imv.desktop image/gif
xdg-mime default imv.desktop image/webp
xdg-mime default imv.desktop image/bmp
xdg-mime default imv.desktop image/tiff

log_info "Setting default PDF viewer to 'Evince'..."
xdg-mime default org.gnome.Evince.desktop application/pdf

# check for $BROWSER and set default web browser to $BROWSER
# when $BROWSER is set we cant change with xdg-settings
if [ -n "$BROWSER" ]; then
    log_info "We cannot change the default web browser when \$BROWSER is set. \n Please check or remove your \$BROWSER environment variable."
else
    log_info "Setting default web browser to '$BROWSER'..."
    xdg-settings set default-web-browser "$BROWSER.desktop"
    xdg-mime default "$BROWSER.desktop" x-scheme-handler/http
    xdg-mime default "$BROWSER.desktop" x-scheme-handler/https
fi

log_info "Setting default video player to 'mpv'..."
xdg-mime default mpv.desktop video/mp4 video/x-msvideo video/x-matroska video/x-flv video/x-ms-wmv video/mpeg video/ogg video/webm video/quicktime video/3gpp video/3gpp2 video/x-ms-asf video/x-ogm+ogg video/x-theora+ogg application/ogg

log_info "Default application setup complete."
