#!/bin/bash
# Orchestrates the execution of various setup scripts.

# Don't use set -e here - we want to continue even if individual scripts fail
# Individual scripts can still use set -e if they want strict error handling

# --- Script Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source centralized logging utilities
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../lib/logging.sh"
source "${SCRIPT_DIR}/../lib/platform.sh"
SETUP_SCRIPT_DIR="$SCRIPT_DIR/setup"
HEADLESS_MODE=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --headless)
                HEADLESS_MODE=true
                shift
                ;;
            *)
                log_warning "Unknown setup orchestration argument '$1' ignored"
                shift
                ;;
        esac
    done
}

# --- Script Execution ---
run_script() {
    local script_name="$1"
    local script_path="$SETUP_SCRIPT_DIR/$script_name"
    if [ -f "$script_path" ]; then
        log_info "Running $script_name..."
        if bash "$script_path"; then
            log_info "$script_name completed successfully"
        else
            log_warning "$script_name failed with exit code $?, continuing with remaining scripts..."
        fi
    else
        log_warning "$script_name not found, skipping."
    fi
}

should_run_script() {
    local script_name="$1"
    local platform
    platform=$(detect_platform)
    local platform_key
    platform_key=$(canonical_platform_key "$platform")

    case "$script_name" in
        pacman-tweaks.sh|steam.sh)
            [[ "$platform_key" == "arch" ]]
            return
            ;;
        default-apps.sh|user-services.sh|applications.sh)
            [[ "$HEADLESS_MODE" != "true" ]]
            return
            ;;
        *)
            return 0
            ;;
    esac
}

parse_args "$@"
log_info "Starting setup orchestration..."

setup_scripts=(
    "default-apps.sh"
    "pacman-tweaks.sh"
    "power-management.sh"
    "steam.sh"
    "system-services.sh"
    "user-services.sh"
    "applications.sh"
)

for script_name in "${setup_scripts[@]}"; do
    if should_run_script "$script_name"; then
        run_script "$script_name"
    else
        log_info "Skipping $script_name for current install mode/platform"
    fi
done

log_info "Setup orchestration complete."
