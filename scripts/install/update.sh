#!/bin/bash
# Updates the entire system: dotfiles, packages, and themes.

set -e

# --- Header and Logging ---
# Colors for output
BLUE='\033[0;34m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1"; }

# --- Migration Setup ---
REPO_ROOT=$(git rev-parse --show-toplevel)
MIGRATIONS_DIR="$REPO_ROOT/migrations"
STATE_DIR="$HOME/.local/state/dotfiles/migrations"

# 1. Update Dotfiles
log_info "Updating dotfiles repository..."
cd "$(dirname "$0")/.." # Move to the root of the dotfiles repo
git pull --autostash
git diff --check || git reset --merge
cd - >/dev/null

# 2. Run Pending Migrations
log_info "Running pending migrations..."
mkdir -p "$STATE_DIR"

if [ -d "$MIGRATIONS_DIR" ]; then
    for file in "$MIGRATIONS_DIR"/*.sh; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            
            # If migration has not been run, run it and record the state
            if [ ! -f "${STATE_DIR}/$filename" ]; then
                log_info "Running migration: $filename"
                # Ensure the migration script is executable before running
                chmod +x "$file"
                source "$file"
                touch "${STATE_DIR}/$filename"
            fi
        fi
    done
fi

# 3. Update System Packages
log_info "Updating system packages with paru..."
paru -Syu --noconfirm

# 4. Update Themes
log_info "Updating all installed themes..."
"$(dirname "$0")/../theme-manager/theme-update"

log_info "System update complete!"
