#!/bin/bash
# Enables essential system-level services.

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# --- List of services to enable ---
services=(
  "bluetooth.service"
  "cups.service"
  "power-profiles-daemon.service"
  "iwd.service"
  "docker.service"
)

log_info "Enabling essential system services..."

for service in "${services[@]}"; do
  if systemctl is-enabled --quiet "$service"; then
    log_info "Service '$service' is already enabled."
  else
    log_info "Enabling service '$service'..."
    sudo systemctl enable "$service"
  fi
done

log_success "System services configured."
