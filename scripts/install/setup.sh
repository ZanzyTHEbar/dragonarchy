#!/bin/bash
# Orchestrates the execution of various setup scripts.

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1"; }

# --- Script Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT_DIR="$SCRIPT_DIR/setup"

# --- Script Execution ---
run_script() {
    local script_name="$1"
    local script_path="$SETUP_SCRIPT_DIR/$script_name"
    if [ -f "$script_path" ]; then
        log_info "Running $script_name..."
        bash "$script_path"
    else
        log_warning "$script_name not found, skipping."
    fi
}

log_info "Starting setup orchestration..."

run_script "default-apps.sh"
run_script "keyboard.sh"
run_script "pacman-tweaks.sh"
run_script "power-management.sh"
run_script "steam.sh"
run_script "system-services.sh"
run_script "user-config.sh"

log_info "Setup orchestration complete."
