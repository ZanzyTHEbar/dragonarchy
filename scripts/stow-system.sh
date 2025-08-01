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

# --- Script Configuration ---
PACKAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../packages" && pwd)"

# --- Packages to Stow ---
SYSTEM_PACKAGES=(
    "plymouth"
)

# --- Stow Logic ---
log_info "Stowing system packages..."

if ! command -v stow &>/dev/null; then
    log_error "Stow is not installed. Please install it first."
    exit 1
fi

cd "$PACKAGES_DIR"

for package in "${SYSTEM_PACKAGES[@]}"; do
    if [ -d "$package" ]; then
        log_info "Stowing $package to /"
        stow -D "$package" -t / 2>/dev/null # Unstow first
        stow "$package" -t /
    else
        log_warning "Package $package not found in $PACKAGES_DIR"
    fi
done

log_success "System packages stowed successfully."
