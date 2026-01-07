#!/usr/bin/env bash
# Updates the entire system: dotfiles, packages, and themes.

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../lib/logging.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/install-state.sh"

REPO_ROOT=$(git rev-parse --show-toplevel)

# 1. Update Dotfiles
log_info "Updating dotfiles repository..."
cd "$REPO_ROOT" # Move to the root of the dotfiles repo
git pull --autostash
git diff --check || git reset --merge
cd - >/dev/null

# 2. Run Pending Migrations
log_info "Running pending migrations..."

"$REPO_ROOT/scripts/install/run-migrations.sh"

# 3. Update System Packages
if command -v paru >/dev/null 2>&1; then
    log_info "Updating system packages with paru..."
    paru -Syu --noconfirm
elif command -v apt-get >/dev/null 2>&1; then
    log_info "Updating system packages with apt-get..."
    sudo apt-get update
    sudo apt-get upgrade -y
else
    log_warning "No supported package manager found (paru/apt-get); skipping package update"
fi

# 4. Update Themes
log_info "Updating all installed themes..."
"$(dirname "$0")/../theme-manager/theme-update"

log_info "System update complete!"
