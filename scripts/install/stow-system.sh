#!/bin/bash
# Handles stowing packages that need to be installed system-wide.

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# --- Packages to Stow ---
# Add global system packages that should be stowed to /
SYSTEM_PACKAGES=("")

# --- Stow Logic ---
log_info "Stowing system packages..."

if ! command -v stow &>/dev/null; then
    log_error "Stow is not installed. Please install it first."
    exit 1
fi

# --- Script Configuration ---
PACKAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../packages" && pwd)"

cd "$PACKAGES_DIR"

# Check if the SYSTEM_PACKAGES array is empty
if [ ${#SYSTEM_PACKAGES[@]} -eq 0 ]; then
    log_warning "No system packages to stow."
    exit 0
fi

for package in "${SYSTEM_PACKAGES[@]}"; do
    if [ -d "$package" ]; then
        log_info "Stowing $package to /"
        stow -D "$package" -t / 2>/dev/null || true
        # Use --adopt to take over existing files safely; ignore sddm/vendor so it doesn't create /vendor
        if [[ "$package" == "sddm" ]]; then
            sudo stow --adopt -t / --ignore='^vendor(/|$)' "$package"
        else
            sudo stow --adopt -t / "$package"
        fi
    else
        log_warning "Package $package not found in $PACKAGES_DIR"
    fi
done

log_success "System packages stowed successfully."
