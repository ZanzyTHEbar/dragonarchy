#!/bin/bash
# Configures PAM authentication for hyprlock.

set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"

PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PAM_CONFIG="$PROJECT_ROOT/packages/hyprland/hyprlock.pam"
PAM_TARGET="/etc/pam.d/hyprlock"

# Check if hyprlock is installed and we're on a Hyprland system
if ! command -v hyprlock &>/dev/null; then
    log_warning "hyprlock not found. Skipping PAM configuration."
    exit 0
fi

# Check if PAM config source exists
if [[ ! -f "$PAM_CONFIG" ]]; then
    log_warning "PAM config source not found at $PAM_CONFIG. Skipping."
    exit 0
fi

log_info "Setting up PAM configuration for hyprlock..."

# Create backup if target exists
if [[ -f "$PAM_TARGET" ]]; then
    sudo cp "$PAM_TARGET" "${PAM_TARGET}.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Created backup of existing PAM configuration"
fi

# Install PAM configuration
log_info "Installing PAM configuration to $PAM_TARGET"
sudo cp "$PAM_CONFIG" "$PAM_TARGET"
sudo chmod 644 "$PAM_TARGET"

# Verify installation
if [[ -f "$PAM_TARGET" ]]; then
    log_success "PAM configuration installed successfully"

    # Test PAM configuration syntax
    if command -v pam-auth-update &>/dev/null; then
        log_info "Validating PAM configuration..."
        if sudo pam-auth-update --test "$PAM_TARGET" &>/dev/null; then
            log_success "PAM configuration validated successfully"
        else
            log_warning "PAM configuration validation failed - please check $PAM_TARGET"
        fi
    fi
else
    log_error "Failed to install PAM configuration"
    exit 1
fi

log_success "PAM configuration for hyprlock setup complete."
