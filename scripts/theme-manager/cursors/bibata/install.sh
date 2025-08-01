#!/usr/bin/env zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)"

# Function to log info messages
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

# Install dependencies
log_info "Installing Bibata cursor theme dependencies..."
bash "$SCRIPT_DIR/../../../install/install_deps.sh"

# Set cursor theme
log_info "Setting Bibata as the default cursor theme..."
bash "$SCRIPT_DIR/set-cursor.sh"

echo "Bibata cursor theme setup complete."
