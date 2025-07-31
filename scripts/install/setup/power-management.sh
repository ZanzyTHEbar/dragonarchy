#!/bin/bash
# Installs power-profiles-daemon and sets the appropriate power profile.

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1" }

log_info "Setting up power management..."

# Install power-profiles-daemon if not already installed
if ! command -v powerprofilesctl &>/dev/null; then
    log_info "Installing power-profiles-daemon..."
    yay -S --noconfirm --needed power-profiles-daemon
fi

# Set power profile based on battery presence
if ls /sys/class/power_supply/BAT* &>/dev/null; then
  log_info "Battery detected. Setting power profile to 'balanced'."
  powerprofilesctl set balanced || true
else
  log_info "No battery detected. Setting power profile to 'performance'."
  powerprofilesctl set performance || true
fi

log_info "Power management setup complete."
