#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Zoom Fix for Hyprland - XWayland Rendering Issue Resolution
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Fixes transparent/blurred Zoom meeting windows on Hyprland by:
# 1. Forcing X11 mode instead of Wayland
# 2. Disabling alpha buffer in Zoom config
# 3. Applying Hyprland window rules to prevent blur
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source logging utilities if available
if [[ -f "$SCRIPT_DIR/../lib/logging.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/../lib/logging.sh"
else
    # Fallback logging functions
    log_info() { echo "ℹ️  $*"; }
    log_success() { echo "✅ $*"; }
    log_warning() { echo "⚠️  $*"; }
    log_error() { echo "❌ $*" >&2; }
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Check if Zoom is installed
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
check_zoom_installed() {
    if ! command -v zoom &>/dev/null && ! [[ -f /opt/zoom/zoom ]]; then
        log_warning "Zoom is not installed on this system"
        log_info "Install Zoom with: yay -S zoom"
        return 1
    fi
    log_success "Zoom installation detected"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Setup Zoom Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
setup_zoom_config() {
    local zoom_config_dir="$HOME/.config/zoomus.conf"
    local source_config="$DOTFILES_ROOT/packages/applications/.zoom/zoomus.conf"
    
    log_info "Setting up Zoom configuration..."
    
    # Backup existing config if present
    if [[ -f "$zoom_config_dir" ]]; then
        log_warning "Existing Zoom config found, creating backup..."
        cp "$zoom_config_dir" "${zoom_config_dir}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Copy new config
    if [[ -f "$source_config" ]]; then
        cp "$source_config" "$zoom_config_dir"
        log_success "Zoom config installed: $zoom_config_dir"
    else
        # Create config inline if source doesn't exist
        log_warning "Source config not found, creating directly..."
        cat > "$zoom_config_dir" <<'EOF'
# Zoom Configuration for Hyprland/Wayland Compatibility
enableAlphaBuffer=false
useSystemTheme=true
EOF
        log_success "Created Zoom config: $zoom_config_dir"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Update Desktop File
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
update_desktop_file() {
    local desktop_file="$HOME/.local/share/applications/zoom.desktop"
    
    log_info "Updating Zoom desktop file to force X11 mode..."
    
    # Create applications directory if it doesn't exist
    mkdir -p "$(dirname "$desktop_file")"
    
    # Create desktop file with X11 enforcement
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
    
    log_success "Desktop file updated: $desktop_file"
    
    # Update desktop database
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
        log_success "Desktop database updated"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Verify Hyprland Window Rules
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verify_window_rules() {
    local windowrules_file="$HOME/.config/hypr/config/windowrules.conf"
    
    log_info "Checking Hyprland window rules for Zoom..."
    
    if [[ ! -f "$windowrules_file" ]]; then
        log_warning "Hyprland window rules file not found: $windowrules_file"
        log_info "Window rules should be applied via stow from dotfiles"
        return 1
    fi
    
    # Check for Zoom-specific rules
    if grep -q "noblur.*zoom" "$windowrules_file"; then
        log_success "Zoom window rules detected in Hyprland config"
    else
        log_warning "Zoom-specific window rules not found"
        log_info "Run: cd $DOTFILES_ROOT && stow -d packages -t ~ hyprland"
        return 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Reload Hyprland Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
reload_hyprland() {
    log_info "Reloading Hyprland configuration..."
    
    if command -v hyprctl &>/dev/null; then
        hyprctl reload 2>/dev/null || {
            log_warning "Could not reload Hyprland via hyprctl"
            log_info "Changes will take effect after logout/login"
            return 1
        }
        log_success "Hyprland configuration reloaded"
    else
        log_warning "hyprctl not found - are you running Hyprland?"
        log_info "Changes will take effect after logout/login"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Function
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
main() {
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Zoom Fix for Hyprland - XWayland Rendering Issues"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    # Check if Zoom is installed
    if ! check_zoom_installed; then
        log_error "Cannot proceed without Zoom installation"
        exit 1
    fi
    
    echo
    
    # Apply fixes
    setup_zoom_config
    update_desktop_file
    verify_window_rules || log_warning "Window rules verification failed - ensure Hyprland dotfiles are stowed"
    
    echo
    
    # Reload Hyprland
    reload_hyprland
    
    echo
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Zoom fix applied successfully!"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    log_info "Next steps:"
    log_info "  1. Close any running Zoom instances"
    log_info "  2. Launch Zoom from application launcher or terminal: zoom"
    log_info "  3. Join a test meeting to verify rendering"
    echo
    log_info "If issues persist, try:"
    log_info "  • Run: QT_QPA_PLATFORM=xcb zoom (force X11 explicitly)"
    log_info "  • Check compositor: hyprctl getoption decoration:blur"
    log_info "  • View Zoom logs: tail -f ~/.zoom/logs/zoom_stdout_stderr.log"
    echo
    log_warning "Note: Zoom will run via XWayland (X11 compatibility layer)"
    log_warning "This is required for stable rendering on Hyprland"
    echo
}

# Run main function
main "$@"

