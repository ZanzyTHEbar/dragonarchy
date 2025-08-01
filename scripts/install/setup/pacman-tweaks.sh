#!/bin/bash
# Applies cosmetic tweaks to /etc/pacman.conf.

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1"; }

log_info "Applying pacman tweaks..."

# Add fun and color to the pacman installer
if ! grep -q "ILoveCandy" /etc/pacman.conf; then
  log_info "Adding 'ILoveCandy' to pacman.conf..."
  sudo sed -i '/^#Color/a ILoveCandy' /etc/pacman.conf
  sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
else
  log_info "'ILoveCandy' already present in pacman.conf."
fi

log_info "Pacman tweaks complete."
