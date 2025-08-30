#!/usr/bin/env bash
# Launch clipse directly without uwsm to avoid environment issues
# This script provides a reliable way to start clipse clipboard manager

set -euo pipefail

# Check if clipse is already running
if pgrep -x clipse >/dev/null 2>&1; then
    echo "clipse is already running"
    exit 0
fi

# Launch clipse as a background process
/usr/bin/clipse -listen &
disown
