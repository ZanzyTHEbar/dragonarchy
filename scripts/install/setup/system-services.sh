#!/bin/bash
# Enables essential system-level services.

# Don't use set -e - we want to continue even if a service fails
# set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"

# --- List of services to enable ---
services=(
  "bluetooth.service"
  "cups.service"
  "iwd.service"
)

log_info "Enabling essential system services..."

# Handle power-profiles-daemon vs TLP conflict at runtime
# Check if TLP is installed - if so, skip power-profiles-daemon and mask it
if command -v tlp &>/dev/null; then
    log_info "TLP detected - skipping power-profiles-daemon.service (conflicts)"
    # Prevent activation of power-profiles-daemon if it happens to be installed anyway
    if systemctl list-unit-files 2>/dev/null | grep -q "^power-profiles-daemon\\.service"; then
        log_info "Masking power-profiles-daemon.service (installed but conflicts with TLP)"
        sudo systemctl stop power-profiles-daemon.service 2>/dev/null || true
        sudo systemctl disable power-profiles-daemon.service 2>/dev/null || true
        sudo systemctl mask power-profiles-daemon.service 2>/dev/null || true
    fi
else
    # TLP not installed - add power-profiles-daemon to services list
    services+=("power-profiles-daemon.service")
    log_info "TLP not detected - adding power-profiles-daemon.service"
fi

# Enable docker service entries when docker packages are already installed.
if systemctl list-unit-files 2>/dev/null | grep -q "^docker.service"; then
    services+=("docker.service")
    log_info "Detected docker.service, adding to service enable list"
fi
if systemctl list-unit-files 2>/dev/null | grep -q "^docker.socket"; then
    services+=("docker.socket")
    log_info "Detected docker.socket, adding to service enable list"
fi

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
