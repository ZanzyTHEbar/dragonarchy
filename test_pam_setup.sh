#!/bin/bash
# Test script to verify PAM setup logic

set -e

# Configuration (same as system_config.sh)
SCRIPT_DIR="$(cd "$(dirname "scripts/install/system_config.sh")" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "=== PAM Setup Test ==="
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "CONFIG_DIR: $CONFIG_DIR"
echo ""

# Check if hyprlock is installed
log_info "Checking if hyprlock is installed..."
if ! command -v hyprlock &>/dev/null 2>&1; then
    log_warning "hyprlock not found, would skip PAM configuration"
    exit 0
else
    log_success "hyprlock found at $(which hyprlock)"
fi

# Define paths (same as in system_config.sh)
pam_config="/etc/pam.d/hyprlock"
config_dir="$CONFIG_DIR/packages/hyprland"
pam_source="$config_dir/hyprlock.pam"

echo ""
log_info "PAM configuration paths:"
echo "  Source: $pam_source"
echo "  Target: $pam_config"
echo ""

# Check if source PAM config exists
if [[ ! -f "$pam_source" ]]; then
    log_warning "PAM config source not found at $pam_source"
    exit 1
else
    log_success "PAM config source found"
    echo "  Contents preview:"
    head -5 "$pam_source" | sed 's/^/    /'
fi

# Check if target exists
if [[ -f "$pam_config" ]]; then
    log_info "Existing PAM config found (would create backup)"
else
    log_info "No existing PAM config (would install fresh)"
fi

echo ""
log_success "PAM setup logic test completed successfully!"
echo "The system_config.sh script should work correctly when run with sudo."
