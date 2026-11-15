#!/usr/bin/env bash
set -euo pipefail
# Compatibility entry: request the same installed owners, never fork a daemon.
exec "$HOME/.local/bin/dragon-clipboard-session" --start
