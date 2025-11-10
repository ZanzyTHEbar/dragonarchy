#!/bin/bash
#
# Verify Package Auto-Detection
#
# This script verifies the automatic package detection mechanism
# and shows which packages will be installed via GNU Stow.

set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PACKAGES_DIR="$DOTFILES_DIR/packages"

# Source logging utilities
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/logging.sh"

# Detect if a package is enabled (has .package marker file)
is_package_enabled() {
    local package="$1"
    local package_dir="$PACKAGES_DIR/$package"
    
    # Package directory must exist
    [[ ! -d "$package_dir" ]] && return 1
    
    # Check for .package marker file
    if [[ -f "$package_dir/.package" ]]; then
        return 0  # Package is enabled
    fi
    
    return 1  # Package is not enabled
}

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Package Detection Verification                     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo

if [[ ! -d "$PACKAGES_DIR" ]]; then
    log_error "Packages directory not found: $PACKAGES_DIR"
    exit 1
fi

log_info "Scanning packages directory: $PACKAGES_DIR"
echo

# Header
printf "%-25s %-15s %-40s\n" "PACKAGE" "ENABLED" "STATUS"
printf "%-25s %-15s %-40s\n" "-------" "-------" "------"

# Track counts
total_packages=0
enabled_count=0

# Scan all package directories
while IFS= read -r package_path; do
    package=$(basename "$package_path")
    total_packages=$((total_packages + 1))
    
    if is_package_enabled "$package"; then
        enabled_count=$((enabled_count + 1))
        printf "%-25s ${GREEN}%-15s${NC} %-40s\n" "$package" "✓ Yes" "will be installed"
    else
        printf "%-25s ${YELLOW}%-15s${NC} %-40s\n" "$package" "✗ No" "marker file missing"
    fi
done < <(find "$PACKAGES_DIR" -maxdepth 1 -type d ! -path "$PACKAGES_DIR" | sort)

echo
log_info "Summary:"
echo "  Total packages: $total_packages"
echo "  Enabled packages: $enabled_count"
echo "  Disabled packages: $((total_packages - enabled_count))"
echo

if [[ $enabled_count -eq 0 ]]; then
    log_warning "No packages are enabled!"
    echo
    log_info "To enable a package:"
    echo "  touch $PACKAGES_DIR/PACKAGE_NAME/.package"
else
    log_success "$enabled_count package(s) will be installed via GNU Stow"
fi

echo
log_info "To enable a package:"
echo "  ${CYAN}touch $PACKAGES_DIR/PACKAGE_NAME/.package${NC}"
echo
log_info "To disable a package:"
echo "  ${CYAN}rm $PACKAGES_DIR/PACKAGE_NAME/.package${NC}"

