#!/usr/bin/env bash
#
# run-convergence.sh - Unified entrypoint for the Ansible + chezmoi control plane
#
# Usage: ./infra/run-convergence.sh --host <hostname> [--dry-run]
#
# Phases:
#   1. Run Ansible foundation playbook
#   2. Run Ansible site playbook (chains all hot-path tranches + edge cases)
#   3. Apply chezmoi user state (requires chezmoi source to be initialized)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source logging library
source "${REPO_ROOT}/scripts/lib/logging.sh"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

HOST_NAME=""
DRY_RUN=false

usage() {
    echo "Usage: $0 --host <hostname> [--dry-run]" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            HOST_NAME="${2:-}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done

if [[ -z "${HOST_NAME}" ]]; then
    log_error "Missing required argument: --host"
    usage
    exit 2
fi

# ---------------------------------------------------------------------------
# Control-plane gating check
# ---------------------------------------------------------------------------

CONTROL_PLANE_MODE_SCRIPT="${REPO_ROOT}/scripts/lib/control-plane-mode.sh"

if [[ -f "${CONTROL_PLANE_MODE_SCRIPT}" ]]; then
    source "${CONTROL_PLANE_MODE_SCRIPT}"

    if ! dotfiles_system_owner_is_ansible 2>/dev/null || ! dotfiles_user_owner_is_chezmoi 2>/dev/null; then
        log_warning "Control-plane owners not set. Expected DOTFILES_SYSTEM_OWNER=ansible and DOTFILES_USER_OWNER=chezmoi"
        log_warning "The script will set them automatically, but operator intent is preferred."
    fi
else
    log_warning "Control-plane mode script not found: ${CONTROL_PLANE_MODE_SCRIPT}"
    log_warning "Skipping owner validation. Proceed with caution."
fi

# Set control-plane environment variables
export DOTFILES_SYSTEM_OWNER=ansible
export DOTFILES_USER_OWNER=chezmoi

# ---------------------------------------------------------------------------
# Validate host exists in Ansible inventory
# ---------------------------------------------------------------------------

INVENTORY_FILE="${REPO_ROOT}/infra/ansible/inventory/hosts.yml"

if [[ ! -f "${INVENTORY_FILE}" ]]; then
    log_fatal "Ansible inventory not found: ${INVENTORY_FILE}"
fi

if ! command -v ansible-inventory >/dev/null 2>&1; then
    log_fatal "ansible-inventory is required to validate the host but is not installed."
fi

if ! command -v chezmoi >/dev/null 2>&1; then
    log_fatal "chezmoi is required for cutover but is not installed."
fi

if ! ansible-inventory -i "${INVENTORY_FILE}" --host "${HOST_NAME}" >/dev/null 2>&1; then
    log_error "Host '${HOST_NAME}' not found in Ansible inventory: ${INVENTORY_FILE}"
    exit 1
fi

log_info "Target host: ${HOST_NAME}"
log_info "Dry-run mode: ${DRY_RUN}"

# ---------------------------------------------------------------------------
# Ansible execution helpers
# ---------------------------------------------------------------------------

ANSIBLE_WRAPPER="${REPO_ROOT}/infra/ansible/run-playbook.sh"

run_ansible_playbook() {
    local playbook="$1"
    shift
    local extra_args=()

    if [[ "${DRY_RUN}" == "true" ]]; then
        extra_args+=(--check --diff)
    fi

    log_step "Running Ansible playbook: ${playbook}"
    "${ANSIBLE_WRAPPER}" "${playbook}" "${extra_args[@]}" "$@"
}

# ---------------------------------------------------------------------------
# Chezmoi execution helpers
# ---------------------------------------------------------------------------

# TODO: Replace with permanent chezmoi sync mechanism.
# During migration, chezmoi source is managed by temporary scripts in
# infra/chezmoi/migration-scripts/. After migration, chezmoi source should
# be initialized once (via chezmoi init or a lightweight sync script) and
# then managed directly via `chezmoi edit` / `chezmoi apply`.
#
# See: docs/HANDOFF-CHEZMOI-ARCHITECTURE-CLEANUP.md

run_chezmoi_apply() {
    log_step "Applying chezmoi state for host '${HOST_NAME}'"

    if [[ "${DRY_RUN}" == "true" ]]; then
        chezmoi diff || true
    else
        chezmoi apply
    fi
}

# ---------------------------------------------------------------------------
# Main convergence phases
# ---------------------------------------------------------------------------

log_step "=== Starting convergence for host '${HOST_NAME}' ==="

# Phase 1: Ansible foundation playbook
# Foundation targets hosts: all by design — it is a global contract check.
run_ansible_playbook "${REPO_ROOT}/infra/ansible/playbooks/foundation.yml"

# Phase 2: Ansible site playbook (chains all hot-path tranches + edge cases)
run_ansible_playbook "${REPO_ROOT}/infra/ansible/playbooks/site.yml" --limit "${HOST_NAME}"

# Phase 3: Apply chezmoi user state
# NOTE: This assumes chezmoi source has been initialized. During migration,
# use migration-scripts/cutover-host.sh --execute. After migration, chezmoi
# source lives in ~/.local/share/chezmoi/ and is managed directly.
run_chezmoi_apply

log_success "=== Convergence complete for host '${HOST_NAME}' ==="
