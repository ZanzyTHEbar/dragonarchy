#!/bin/bash
# Compatibility entry point: the managed missing-only owner is authoritative.
set -euo pipefail
owner="${HOME}/.local/libexec/dragon/mime-defaults"
if [[ ! -x "$owner" ]]; then
    printf '%s\n' 'Default applications require the managed desktop payload; no legacy overwrite fallback.' >&2
    exit 1
fi
exec "$owner"
