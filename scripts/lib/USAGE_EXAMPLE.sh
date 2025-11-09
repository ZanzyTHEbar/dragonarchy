#!/usr/bin/env bash
#
# USAGE_EXAMPLE.sh - Template showing how to use the centralized logging.sh
#
# This is an example template. Copy this pattern to your actual scripts.
#

set -euo pipefail

# Get the directory where THIS script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the logging utilities
# Adjust the path based on your script's location relative to scripts/lib/logging.sh
#
# Examples:
# - If your script is in scripts/: source "${SCRIPT_DIR}/lib/logging.sh"
# - If your script is in scripts/subdir/: source "${SCRIPT_DIR}/../lib/logging.sh"
# - If your script is in root/: source "${SCRIPT_DIR}/scripts/lib/logging.sh"

source "${SCRIPT_DIR}/logging.sh"  # Adjust this path as needed!

# Now you can use all the logging functions!
main() {
    log_info "Starting example script..."
    log_step "Step 1: Doing something"
    
    if [[ -d "/some/path" ]]; then
        log_success "Path exists!"
    else
        log_warning "Path doesn't exist"
    fi
    
    log_error "This is an error message"
    log_success "Script completed successfully!"
}

main "$@"

