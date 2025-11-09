#!/bin/bash
# Enable Advanced Gestures After Plugin Installation
# Run this after: bash ~/dotfiles/hosts/firedragon/setup.sh

set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../scripts/lib/logging.sh"

GESTURES_CONF="$HOME/.config/hypr/config/gestures.conf"

echo
log_info "🔍 Checking for installed gesture plugins..."
echo

# Check if hyprgrass plugin is loaded
if hyprctl plugin list 2>/dev/null | grep -q "hyprgrass"; then
    log_success "hyprgrass plugin is loaded"
    HYPRGRASS_AVAILABLE=true
else
    log_warning "hyprgrass plugin not found"
    log_info "Install it by running: bash ~/dotfiles/hosts/firedragon/setup.sh"
    HYPRGRASS_AVAILABLE=false
fi

# Check if hyprexpo is available
if hyprctl plugin list 2>/dev/null | grep -q "hyprexpo"; then
    log_success "hyprexpo plugin is available"
    HYPREXPO_AVAILABLE=true
else
    log_warning "hyprexpo plugin not found (might be built-in or unavailable in this Hyprland version)"
    HYPREXPO_AVAILABLE=false
fi

echo
log_info "📝 Enabling gestures in configuration..."
echo

# Backup original file
cp "$GESTURES_CONF" "$GESTURES_CONF.backup"
log_info "Created backup: $GESTURES_CONF.backup"

# Enable hyprexpo pinch gestures if available
if [ "$HYPREXPO_AVAILABLE" = true ]; then
    sed -i 's/# bind = , gesture:pinch:2:o, hyprexpo:expo, toggle/bind = , gesture:pinch:2:o, hyprexpo:expo, toggle/' "$GESTURES_CONF"
    sed -i 's/# bind = , gesture:pinch:2:i, hyprexpo:expo, toggle/bind = , gesture:pinch:2:i, hyprexpo:expo, toggle/' "$GESTURES_CONF"
    log_success "Enabled hyprexpo pinch gestures"
else
    log_info "Skipping hyprexpo gestures (plugin not available)"
fi

# Enable hyprgrass edge swipes if available
if [ "$HYPRGRASS_AVAILABLE" = true ]; then
    # Uncomment the entire plugin block
    sed -i '/# plugin {/,/# }/s/^# //' "$GESTURES_CONF"
    log_success "Enabled hyprgrass edge swipes and touch gestures"
else
    log_info "Skipping hyprgrass gestures (plugin not installed)"
fi

echo
log_info "🔄 Reloading Hyprland configuration..."
if hyprctl reload 2>/dev/null; then
    log_success "Hyprland configuration reloaded"
else
    log_warning "Could not reload Hyprland automatically. Please logout/login or run: hyprctl reload"
fi

echo
log_success "✅ Gesture configuration updated!"
echo
log_info "📋 Enabled Gestures:"

if [ "$HYPRGRASS_AVAILABLE" = true ]; then
    echo "  ✅ Edge swipes:"
    echo "     • Swipe from bottom → App launcher"
    echo "     • Swipe from right → Notifications"
    echo "     • Swipe from top → Toggle waybar"
    echo "     • Long press + drag → Move window"
fi

if [ "$HYPREXPO_AVAILABLE" = true ]; then
    echo "  ✅ Pinch gestures:"
    echo "     • Pinch out → Workspace overview"
    echo "     • Pinch in → Return from overview"
fi

echo
log_info "🧪 Test your gestures:"
echo "  • Try swiping from the bottom edge of your screen"
echo "  • Try pinching out with 2 fingers"
echo "  • Run 'sudo libinput debug-events' to see live gesture events"
echo
log_info "📄 Configuration file: $GESTURES_CONF"
log_info "📦 Backup saved to: $GESTURES_CONF.backup"
echo

if [ "$HYPRGRASS_AVAILABLE" = false ] || [ "$HYPREXPO_AVAILABLE" = false ]; then
    echo
    log_warning "⚠️  Some plugins are missing. To install them:"
    echo "  1. Run: bash ~/dotfiles/hosts/firedragon/setup.sh"
    echo "  2. Logout and login"
    echo "  3. Run this script again: bash ~/dotfiles/hosts/firedragon/enable-advanced-gestures.sh"
    echo
fi

