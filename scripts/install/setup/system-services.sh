#!/bin/bash
# Enables essential system-level services.

# Don't use set -e - we want to continue even if a service fails
# set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"

# --- List of services to enable ---
# "docker.service" - TODO - need to add docker installation to setup BEFORE setting up the service
services=(
  "bluetooth.service"
  "cups.service"
  "iwd.service"
)

# Add power-profiles-daemon ONLY if TLP is not installed (they conflict)
if ! command -v tlp &>/dev/null; then
    services+=("power-profiles-daemon.service")
    log_info "Adding power-profiles-daemon.service (TLP not detected)"
else
    log_info "Skipping power-profiles-daemon.service (TLP is installed)"
fi

log_info "Enabling essential system services..."

for service in "${services[@]}"; do
  # Check if service exists before trying to enable
  if ! systemctl list-unit-files | grep -q "^$service"; then
    log_warning "Service '$service' does not exist, skipping..."
    continue
  fi
  
  if systemctl is-enabled --quiet "$service" 2>/dev/null; then
    log_info "Service '$service' is already enabled."
  else
    log_info "Enabling service '$service'..."
    if sudo systemctl enable "$service" 2>/dev/null; then
      log_success "Enabled '$service'"
    else
      log_warning "Failed to enable '$service' - may need manual setup"
    fi
  fi
done

log_success "System services configured."
