#!/bin/bash
# Enables the multilib repository for 32-bit compatibility, required by Steam.

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1" }

log_info "Enabling multilib repository for Steam..."

if grep -q "^\s*#\s*\[multilib\]" /etc/pacman.conf; then
  sudo sed -i '/^\s*#\[multilib\]/,/^$/{s/^\s*#//}' /etc/pacman.conf
  log_info "Multilib repository enabled. Updating pacman..."
  sudo pacman -Sy
else
  log_info "Multilib repository already enabled."
fi

log_info "Steam setup complete. You can install Steam via the main install script or manually."
