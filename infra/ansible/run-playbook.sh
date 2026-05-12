#!/usr/bin/env bash
#
# run-playbook.sh - Ansible playbook wrapper with local-connection auto-detection
#
# Usage: ./run-playbook.sh <playbook> [ansible-playbook args...]
#
# Automatically injects --connection=local when --limit targets the current
# machine, avoiding unnecessary SSH-to-self while preserving SSH for remote
# execution from a control node.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export ANSIBLE_CONFIG="${SCRIPT_DIR}/ansible.cfg"

# Source logging library
source "${REPO_ROOT}/scripts/lib/logging.sh"

# ---------------------------------------------------------------------------
# Local target detection
# ---------------------------------------------------------------------------

is_local_target() {
    local target="$1"
    local current_short
    local current_fqdn

    current_short=$(hostname -s 2>/dev/null || hostname)
    current_fqdn=$(hostname -f 2>/dev/null || hostname)

    if [[ "${target}" == "localhost" ]] || \
       [[ "${target}" == "127.0.0.1" ]] || \
       [[ "${target}" == "::1" ]] || \
       [[ "${target}" == "${current_short}" ]] || \
       [[ "${target}" == "${current_fqdn}" ]]; then
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

PLAYBOOK=""
LIMIT=""
PASSTHROUGH_ARGS=()

# Parse arguments to extract --limit and the playbook path
while [[ $# -gt 0 ]]; do
    case "$1" in
        --limit)
            LIMIT="${2:-}"
            PASSTHROUGH_ARGS+=("$1" "$2")
            shift 2
            ;;
        --limit=*)
            LIMIT="${1#--limit=}"
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
        -*)
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
        *)
            if [[ -z "${PLAYBOOK}" ]]; then
                PLAYBOOK="$1"
            else
                PASSTHROUGH_ARGS+=("$1")
            fi
            shift
            ;;
    esac
done

if [[ -z "${PLAYBOOK}" ]]; then
    log_error "No playbook specified"
    echo "Usage: $0 <playbook> [ansible-playbook args...]" >&2
    exit 2
fi

INVENTORY_FILE="${SCRIPT_DIR}/inventory/hosts.yml"

if [[ ! -f "${INVENTORY_FILE}" ]]; then
    log_fatal "Ansible inventory not found: ${INVENTORY_FILE}"
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
    log_fatal "ansible-playbook is required but is not installed."
fi

# ---------------------------------------------------------------------------
# Connection detection
# ---------------------------------------------------------------------------

CONNECTION_ARGS=()

if [[ -n "${LIMIT}" ]] && is_local_target "${LIMIT}"; then
    CONNECTION_ARGS+=(--connection=local)
    log_info "Detected local execution for '${LIMIT}' — using local connection (no SSH)"
fi

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------

ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK}" "${CONNECTION_ARGS[@]}" "${PASSTHROUGH_ARGS[@]}"
