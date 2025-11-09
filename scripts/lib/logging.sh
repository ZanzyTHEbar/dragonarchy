#!/usr/bin/env bash
#
# logging.sh - Centralized logging utilities for dotfiles scripts
# 
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"
#        or: source "${DOTFILES_ROOT}/scripts/lib/logging.sh"
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Optional: Additional utility functions you might find useful
log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "\033[0;35m[DEBUG]${NC} $1"
    fi
}

log_fatal() {
    echo -e "${RED}[FATAL]${NC} $1"
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}