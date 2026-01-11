#!/bin/bash
# Handles stowing packages that need to be installed system-wide.
#
# System packages are auto-detected via a `.package` marker file with `scope=system` in `packages/<pkg>/`.
#
# This avoids accidentally stowing system packages into $HOME (user-level stow pass uses `.package` with default scope=user).

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../lib/logging.sh"

PACKAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../packages" && pwd)"

is_system_scoped_package() {
    local pkg_dir="$1"
    local marker="$pkg_dir/.package"
    [[ -f "$marker" ]] || return 1
    # Accept either `scope=system` or `scope: system` (allow whitespace/comments)
    grep -Eq '^[[:space:]]*scope[[:space:]]*[:=][[:space:]]*system[[:space:]]*$' "$marker"
}

# Auto-detect system packages
SYSTEM_PACKAGES=()
while IFS= read -r -d '' marker; do
    pkg_dir="$(dirname "$marker")"
    if is_system_scoped_package "$pkg_dir"; then
        pkg_name="$(basename "$pkg_dir")"
        SYSTEM_PACKAGES+=("$pkg_name")
    fi
done < <(find "$PACKAGES_DIR" -maxdepth 2 -type f -name ".package" -print0 2>/dev/null | sort -z)

# --- Stow Logic ---
log_info "Stowing system packages..."

if ! command -v stow &>/dev/null; then
    log_error "Stow is not installed. Please install it first."
    exit 1
fi

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
