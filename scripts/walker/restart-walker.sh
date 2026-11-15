#!/usr/bin/env bash
set -euo pipefail
# No pgrep/kill/new-process fallback: the user manager owns the launcher.
exec systemctl --user restart walker.service
