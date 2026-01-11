#!/bin/bash
# Installs power management tools (TLP for laptops, power-profiles-daemon for desktops)

# Don't use set -e - we want to continue even if commands fail
# set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"

log_info "Setting up power management..."

# Check if TLP is installed (laptop setup)
if command -v tlp &>/dev/null; then
    log_info "TLP detected - using TLP for power management (laptop configuration)"
    log_info "Skipping power-profiles-daemon (conflicts with TLP)"

    # If power-profiles-daemon is installed/enabled anyway, disable it to avoid conflicts.
    if systemctl list-unit-files 2>/dev/null | grep -q "^power-profiles-daemon\\.service"; then
        # power-profiles-daemon can also be started via D-Bus activation even if "disabled".
        # Masking prevents both explicit and activation-based starts.
        log_info "Ensuring power-profiles-daemon.service is stopped + masked (conflicts with TLP)..."
        sudo systemctl stop power-profiles-daemon.service 2>/dev/null || true
        sudo systemctl disable power-profiles-daemon.service 2>/dev/null || true
        sudo systemctl mask power-profiles-daemon.service 2>/dev/null || log_warning "Could not mask power-profiles-daemon (may keep conflicting with TLP)"
    fi
    
    # Start TLP if not running
    if ! systemctl is-active --quiet tlp.service 2>/dev/null; then
        log_info "Starting TLP service..."
        if systemctl list-unit-files 2>/dev/null | grep -q "^tlp\\.service"; then
            sudo systemctl start tlp.service 2>/dev/null || {
                log_warning "Could not start tlp.service via systemd; falling back to 'sudo tlp start'"
                sudo tlp start 2>/dev/null || log_warning "Fallback 'sudo tlp start' failed"
            }
        else
            log_warning "tlp.service unit not found; trying 'sudo tlp start'"
            sudo tlp start 2>/dev/null || log_warning "Could not start TLP via 'sudo tlp start'"
        fi
    fi
    
elif command -v powerprofilesctl &>/dev/null; then
    # power-profiles-daemon already installed
    log_info "power-profiles-daemon detected - configuring..."

# Set power profile based on battery presence
    if ls /sys/class/power_supply/BAT* &>/dev/null 2>&1; then
  log_info "Battery detected. Setting power profile to 'balanced'."
        powerprofilesctl set balanced 2>/dev/null || true
else
  log_info "No battery detected. Setting power profile to 'performance'."
        powerprofilesctl set performance 2>/dev/null || true
    fi
else
    # Neither TLP nor power-profiles-daemon installed
    log_info "No power management tool detected"
    log_info "For desktops: power-profiles-daemon will be installed from hyprland packages"
    log_info "For laptops: TLP is installed by host-specific setup (e.g., firedragon)"
fi

log_info "Power management setup complete."
