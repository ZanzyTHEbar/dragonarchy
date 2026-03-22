#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../scripts/lib/logging.sh"

log_info "Running generic headless host setup..."
log_info "No host-specific actions are required for terminal-only installs."
