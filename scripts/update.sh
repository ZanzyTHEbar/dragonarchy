#!/bin/bash
# Updates the entire system: dotfiles, packages, and themes.

set -e

# --- Header and Logging ---
# Colors for output
BLUE='\033[0;34m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1" }

# 1. Update Dotfiles
log_info "Updating dotfiles repository..."
cd "$(dirname "$0")/.." # Move to the root of the dotfiles repo
git pull --autostash
git diff --check || git reset --merge
cd - >/dev/null

# 2. Update System Packages
log_info "Updating system packages with yay..."
yay -Syu --noconfirm

# 3. Update Themes
log_info "Updating all installed themes..."
"$(dirname "$0")/../packages/theme-manager/bin/theme-update"

log_info "System update complete!"
