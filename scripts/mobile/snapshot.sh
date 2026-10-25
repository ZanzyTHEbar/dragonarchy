#!/usr/bin/env bash
# Capture only declared mobile files. Requires explicit guest home and backup.
set -euo pipefail

exec python3 "$(dirname "${BASH_SOURCE[0]}")/managed-files.py" snapshot "$@"
