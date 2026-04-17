#!/usr/bin/env bash
# Compatibility shim for the newer read-only validation probe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TARGET_SCRIPT="${PROJECT_ROOT}/tests/vm/proxmox-validation/firedragon-suspend-verify.sh"

printf '%s\n' "hosts/firedragon/verify-suspend-fix.sh is deprecated."
printf '%s\n' "Forwarding to ${TARGET_SCRIPT}."

exec "${TARGET_SCRIPT}"
