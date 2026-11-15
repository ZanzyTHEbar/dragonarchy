#!/usr/bin/env bash
# Restore declared mobile files; default mode only prints a plan.
set -euo pipefail

exec python3 "$(dirname "${BASH_SOURCE[0]}")/managed-files.py" restore "$@"
