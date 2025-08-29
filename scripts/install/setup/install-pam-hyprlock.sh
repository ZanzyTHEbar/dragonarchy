#!/bin/bash
# Standalone PAM configuration installer for hyprlock
# This script can be run independently or as part of the main setup

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PAM_CONFIG="$PROJECT_ROOT/packages/hyprland/hyprlock.pam"
PAM_TARGET="/etc/pam.d/hyprlock"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script requires root privileges to install PAM configuration"
    log_info "Please run: sudo $0"
    exit 1
fi

log_info "Installing PAM configuration for hyprlock..."

# Check if hyprlock is installed
if ! command -v hyprlock &>/dev/null 2>&1; then
    log_warning "hyprlock not found. Installing PAM config anyway (it will be used when hyprlock is installed)"
fi

# Check if PAM config source exists
if [[ ! -f "$PAM_CONFIG" ]]; then
    log_error "PAM config source not found at $PAM_CONFIG"
    log_info "Make sure you're running this from the dotfiles root directory"
    exit 1
fi

# Create backup if target exists
if [[ -f "$PAM_TARGET" ]]; then
    BACKUP_FILE="${PAM_TARGET}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$PAM_TARGET" "$BACKUP_FILE"
    log_info "Created backup: $BACKUP_FILE"
fi

# Install PAM configuration
cp "$PAM_CONFIG" "$PAM_TARGET"
chmod 644 "$PAM_TARGET"

# Verify installation
if [[ -f "$PAM_TARGET" ]]; then
    log_success "PAM configuration installed successfully"

    # Show installed configuration
    echo "Installed PAM configuration:"
    echo "------------------------"
    cat "$PAM_TARGET"
    echo "------------------------"

    # Test PAM configuration if possible
    if command -v pam-auth-update &>/dev/null 2>&1; then
        log_info "Validating PAM configuration..."
        if pam-auth-update --test "$PAM_TARGET" &>/dev/null 2>&1; then
            log_success "PAM configuration validated successfully"
        else
            log_warning "PAM configuration validation failed - please check $PAM_TARGET"
        fi
    fi

    log_success "PAM authentication for hyprlock is now configured!"
    log_info "You can test it by running: hyprlock"
else
    log_error "Failed to install PAM configuration"
    exit 1
fi
