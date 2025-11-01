#!/bin/bash
#
# Verify Hyprland Host Detection
# 
# This script tests the automatic Hyprland host detection mechanism
# and shows which hosts will receive Hyprland packages.

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
HOSTS_DIR="$DOTFILES_DIR/hosts"

# Source the detection functions from install_deps.sh
# We'll reimplement them here to avoid sourcing the entire script
is_hyprland_host() {
    local hostname="$1"
    local host_dir="$HOSTS_DIR/$hostname"
    
    # Host directory must exist
    [[ ! -d "$host_dir" ]] && return 1
    
    # Method 1: Check for explicit marker files
    if [[ -f "$host_dir/.hyprland" ]] || [[ -f "$host_dir/HYPRLAND" ]]; then
        echo "marker"
        return 0
    fi
    
    # Method 2: Check if setup.sh mentions Hyprland
    if [[ -f "$host_dir/setup.sh" ]]; then
        if grep -qi "hyprland\|hyprlock\|hypridle\|waybar" "$host_dir/setup.sh"; then
            echo "setup.sh"
            return 0
        fi
    fi
    
    # Method 3: Check for Hyprland config directories in docs
    if [[ -d "$host_dir/docs" ]]; then
        if find "$host_dir/docs" -type f -name "*.md" -exec grep -qi "hyprland" {} \; 2>/dev/null; then
            echo "docs"
            return 0
        fi
    fi
    
    # Not a Hyprland host
    return 1
}

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Hyprland Host Detection Verification                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo

if [[ ! -d "$HOSTS_DIR" ]]; then
    echo -e "${RED}Error: Hosts directory not found: $HOSTS_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}Scanning hosts directory: ${NC}$HOSTS_DIR"
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
    
    detection_method=$(is_hyprland_host "$host" 2>/dev/null) && detected=true || detected=false
    
    if [[ "$detected" == "true" ]]; then
        hyprland_count=$((hyprland_count + 1))
        printf "%-20s ${GREEN}%-15s${NC} %-40s\n" "$host" "✓ Yes" "$detection_method"
    else
        printf "%-20s ${YELLOW}%-15s${NC} %-40s\n" "$host" "✗ No" "not detected"
    fi
done < <(find "$HOSTS_DIR" -maxdepth 1 -type d ! -path "$HOSTS_DIR" | sort)

echo
echo -e "${BLUE}Summary:${NC}"
echo "  Total hosts: $total_hosts"
echo "  Hyprland hosts: $hyprland_count"
echo "  Non-Hyprland hosts: $((total_hosts - hyprland_count))"
echo

# Current host detection
current_host=$(hostname | cut -d. -f1)
echo -e "${BLUE}Current host:${NC} $current_host"

if [[ -d "$HOSTS_DIR/$current_host" ]]; then
    detection_method=$(is_hyprland_host "$current_host" 2>/dev/null) && detected=true || detected=false
    
    if [[ "$detected" == "true" ]]; then
        echo -e "  Status: ${GREEN}Will receive Hyprland packages${NC}"
        echo -e "  Detection method: $detection_method"
    else
        echo -e "  Status: ${YELLOW}Will NOT receive Hyprland packages${NC}"
        echo
        echo -e "${YELLOW}To enable Hyprland for this host:${NC}"
        echo "  1. Create marker file: touch $HOSTS_DIR/$current_host/.hyprland"
        echo "  2. Re-run installation"
    fi
else
    echo -e "  Status: ${RED}No host configuration found${NC}"
    echo
    echo -e "${YELLOW}To create configuration:${NC}"
    echo "  mkdir -p $HOSTS_DIR/$current_host"
    echo "  touch $HOSTS_DIR/$current_host/.hyprland  # For Hyprland support"
    echo "  touch $HOSTS_DIR/$current_host/setup.sh"
fi

echo
echo -e "${BLUE}Detection Methods:${NC}"
echo "  marker     - Has .hyprland or HYPRLAND file (most explicit)"
echo "  setup.sh   - setup.sh mentions hyprland/waybar/etc (auto-detected)"
echo "  docs       - Documentation mentions Hyprland (auto-detected)"
echo
echo -e "${BLUE}For more information:${NC}"
echo "  cat $HOSTS_DIR/README.md"

