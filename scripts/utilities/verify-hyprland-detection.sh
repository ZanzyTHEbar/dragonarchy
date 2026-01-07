#!/bin/bash
#
# Verify Hyprland Host Detection
#
# This script tests the automatic Hyprland host detection mechanism
# and shows which hosts will receive Hyprland packages.

set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
HOSTS_DIR="$DOTFILES_DIR/hosts"

# Source logging utilities
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/logging.sh"

# Source shared host detection helpers
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/hosts.sh"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Hyprland Host Detection Verification                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo

if [[ ! -d "$HOSTS_DIR" ]]; then
    log_error "Hosts directory not found: $HOSTS_DIR"
    exit 1
fi

log_info "Scanning hosts directory: $HOSTS_DIR"
echo

# Header
printf "%-20s %-15s %-40s\n" "HOST" "HYPRLAND" "DETECTION METHOD"
printf "%-20s %-15s %-40s\n" "----" "--------" "----------------"

# Track counts
total_hosts=0
hyprland_count=0

# Scan all host directories
while IFS= read -r host_path; do
    host=$(basename "$host_path")
    total_hosts=$((total_hosts + 1))
    
    detection_method=$(hyprland_detection_method "$HOSTS_DIR" "$host" 2>/dev/null) && detected=true || detected=false
    
    if [[ "$detected" == "true" ]]; then
        hyprland_count=$((hyprland_count + 1))
        printf "%-20s ${GREEN}%-15s${NC} %-40s\n" "$host" "✓ Yes" "$detection_method"
    else
        printf "%-20s ${YELLOW}%-15s${NC} %-40s\n" "$host" "✗ No" "not detected"
    fi
done < <(find "$HOSTS_DIR" -maxdepth 1 -type d ! -path "$HOSTS_DIR" | sort)

echo
log_info "Summary:"
echo "  Total hosts: $total_hosts"
echo "  Hyprland hosts: $hyprland_count"
echo "  Non-Hyprland hosts: $((total_hosts - hyprland_count))"
echo

# Current host detection
current_host=$(hostname | cut -d. -f1)
log_info "Current host: $current_host"

if [[ -d "$HOSTS_DIR/$current_host" ]]; then
    detection_method=$(hyprland_detection_method "$HOSTS_DIR" "$current_host" 2>/dev/null) && detected=true || detected=false
    
    if [[ "$detected" == "true" ]]; then
        log_success "Will receive Hyprland packages"
        echo "  Detection method: $detection_method"
    else
        log_warning "Will NOT receive Hyprland packages"
        echo
        log_warning "To enable Hyprland for this host:"
        echo "  1. Create marker file: touch $HOSTS_DIR/$current_host/.hyprland"
        echo "  2. Re-run installation"
    fi
else
    log_error "No host configuration found"
    echo
    log_warning "To create configuration:"
    echo "  mkdir -p $HOSTS_DIR/$current_host"
    echo "  touch $HOSTS_DIR/$current_host/.hyprland  # For Hyprland support"
    echo "  touch $HOSTS_DIR/$current_host/setup.sh"
fi

echo
log_info "Detection Methods:"
echo "  marker     - Has .hyprland or HYPRLAND file (most explicit)"
echo "  setup.sh   - setup.sh mentions hyprland/waybar/etc (auto-detected)"
echo "  docs       - Documentation mentions Hyprland (auto-detected)"
echo
log_info "For more information:"
echo "  cat $HOSTS_DIR/README.md"

