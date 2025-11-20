#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Application-Specific Configuration and Fixes
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# This script applies application-specific fixes and configurations
# that are required for proper operation on Hyprland/Wayland
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"
source "${SCRIPT_DIR}/../../lib/install-state.sh"

# Detect if running on Hyprland
is_hyprland() {
    [[ "${XDG_CURRENT_DESKTOP:-}" == "Hyprland" ]] || \
    [[ "${XDG_SESSION_DESKTOP:-}" == "Hyprland" ]] || \
    command -v hyprctl &>/dev/null
}

# Check if Zoom is installed
is_zoom_installed() {
    command -v zoom &>/dev/null || [[ -f /opt/zoom/zoom ]]
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Zoom Fix for Hyprland
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
setup_zoom_fix() {
    log_info "Applying Zoom fix for Hyprland..."
    
    # Check if we need to apply the fix
    if ! is_hyprland; then
        log_info "Not running Hyprland, skipping Zoom fix"
        return 0
    fi
    
    if ! is_zoom_installed; then
        log_info "Zoom not installed, skipping fix"
        return 0
    fi
    
    # Create Zoom configuration directory
    local zoom_config="$HOME/.config/zoomus.conf"
    
    # Backup existing config if present and different
    if [[ -f "$zoom_config" ]]; then
        if ! grep -q "enableAlphaBuffer=false" "$zoom_config" 2>/dev/null; then
            log_info "Backing up existing Zoom config..."
            cp "$zoom_config" "${zoom_config}.backup.$(date +%Y%m%d_%H%M%S)"
        fi
    fi
    
    # Create/update Zoom config
    log_info "Creating Zoom configuration..."
    cat > "$zoom_config" <<'EOF'
# Zoom Configuration for Hyprland/Wayland Compatibility
# See: docs/ZOOM_HYPRLAND_FIX.md for details

# Disable alpha buffer to prevent transparency issues
enableAlphaBuffer=false

# Use system theme for Qt integration
useSystemTheme=true
EOF
    
    # Create/update desktop file
    local desktop_file="$HOME/.local/share/applications/zoom.desktop"
    mkdir -p "$(dirname "$desktop_file")"
    
    log_info "Creating Zoom desktop launcher..."
    cat > "$desktop_file" <<'EOF'
[Desktop Entry]
Version=1.0
Name=Zoom
Comment=Zoom video conferencing (X11 mode for Hyprland compatibility)
Exec=env QT_QPA_PLATFORM=xcb QT_AUTO_SCREEN_SCALE_FACTOR=1 /opt/zoom/zoom %U
Terminal=false
Type=Application
Icon=/usr/share/pixmaps/Zoom.png
Categories=Network;Video;AudioVideo;
StartupNotify=false
MimeType=x-scheme-handler/zoommtg;x-scheme-handler/zoomphonecall;x-scheme-handler/zoomus;
StartupWMClass=zoom
EOF
    
    # Update desktop database
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
    
    log_success "Zoom fix applied successfully"
    log_info "Zoom will now run in X11 mode via XWayland"
    log_info "See docs/ZOOM_HYPRLAND_FIX.md for troubleshooting"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Future Application Fixes Can Be Added Here
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Example structure for additional application fixes:
# setup_app_name_fix() {
#     log_info "Applying fix for AppName..."
#     # ... implementation ...
#     log_success "AppName fix applied"
# }

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Function
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
main() {
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Application Configuration and Fixes"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    # Apply Zoom fix with idempotency tracking
    if ! is_step_completed "applications-zoom-fix"; then
        setup_zoom_fix && mark_step_completed "applications-zoom-fix"
    else
        log_info "✓ Zoom fix already applied (skipped)"
        # Still verify config exists
        if is_zoom_installed && is_hyprland; then
            if [[ ! -f "$HOME/.config/zoomus.conf" ]]; then
                log_warning "Zoom config missing, re-applying fix..."
                reset_step "applications-zoom-fix"
                setup_zoom_fix && mark_step_completed "applications-zoom-fix"
            fi
        fi
    fi
    echo
    
    # Add future application fixes here with similar pattern:
    # if ! is_step_completed "applications-app-name-fix"; then
    #     setup_app_name_fix && mark_step_completed "applications-app-name-fix"
    # else
    #     log_info "✓ AppName fix already applied (skipped)"
    # fi
    # echo
    
    log_success "Application configuration completed"
}

# Run main function
main "$@"

