#!/usr/bin/env bash
#
# run-playbook.sh - Ansible playbook wrapper with inventory-bound connections
#
# Usage: ./run-playbook.sh <playbook> [ansible-playbook args...]
#
# Uses the inventory target connection for every limited target. Query or parse
# failures abort instead of guessing from the controller hostname.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
export ANSIBLE_CONFIG="${SCRIPT_DIR}/ansible.cfg"

# Source logging library
source "${REPO_ROOT}/scripts/lib/logging.sh"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

PLAYBOOK=""
LIMIT=""
LIMIT_SET=false
REQUESTED_CONNECTION=""
EXPLICIT_CONNECTION=false
INSPECTION_ONLY=false
SELECTED_USER=""
EXTRA_VARS_USER=""
EXTRA_VARS_KV_PARSEABLE=true
TUPLE_PROFILE=""
TUPLE_USER=""
TUPLE_HOME=""
TUPLE_SOURCE=""
TUPLE_CONNECTION=""
PASSTHROUGH_ARGS=()

canonicalize_playbook_path() {
    local supplied="$1"
    local candidate resolved

    if [[ "${supplied}" == /* ]]; then
        candidate="${supplied}"
    else
        candidate="$(pwd -P)/${supplied}"
        if [[ ! -e "${candidate}" && ! -L "${candidate}" ]]; then
            candidate="${SCRIPT_DIR}/${supplied}"
        fi
    fi

    resolved="$(readlink -f -- "${candidate}" 2>/dev/null)" || {
        log_error "Unable to resolve playbook path: ${supplied}" >&2
        return 2
    }
    if [[ ! -f "${resolved}" ]]; then
        log_error "Playbook path is not a regular file: ${supplied}" >&2
        return 2
    fi

    case "${resolved}" in
        "${SCRIPT_DIR}/playbooks/foundation.yml"|"${SCRIPT_DIR}/playbooks/site.yml"|"${SCRIPT_DIR}/playbooks/update.yml")
            printf '%s' "${resolved}"
            ;;
        *)
            log_error "Unsupported playbook path: ${supplied}" >&2
            return 2
            ;;
    esac
}

record_selected_user() {
    local user="$1"
    [[ -n "${user}" ]] || log_fatal "Selected user must be non-empty."
    [[ "${user}" != root ]] || log_fatal "Refusing root as a selected user."
    if [[ -n "${SELECTED_USER}" && "${SELECTED_USER}" != "${user}" ]]; then
        log_fatal "Selected user values do not match."
    fi
    SELECTED_USER="${user}"
}

extract_target_tuple() {
    local extra_vars="$1"
    local token
    local token_key
    local tuple_value
    local trimmed
    local -a tokens=()
    if [[ "${extra_vars}" == *$'\n'* || "${extra_vars}" == *$'\r'* ]]; then
        log_error "extra-vars payloads cannot contain newlines."
        exit 2
    fi
    trimmed="${extra_vars#${extra_vars%%[![:space:]]*}}"
    case "${trimmed:0:1}" in
        \{|\[|@|-)
            EXTRA_VARS_KV_PARSEABLE=false
            return 0
            ;;
    esac
    read -r -a tokens <<<"${extra_vars}"
    if [[ ${#tokens[@]} -eq 0 ]]; then
        EXTRA_VARS_KV_PARSEABLE=false
        return 0
    fi
    for token in "${tokens[@]}"; do
        if [[ "${token}" != *=* || -z "${token%%=*}" || "${token%%=*}" == *:* ]]; then
            EXTRA_VARS_KV_PARSEABLE=false
            return 0
        fi
        token_key="${token%%=*}"
        case "${token_key}" in
            ansible_*|inventory_hostname|inventory_hostname_*|groups|hostvars|group_names|inventory_dir|inventory_file|playbook_dir|role_path)
                log_error "Reserved extra-vars key is not accepted: ${token_key}"
                exit 2
                ;;
            dotfiles_target_profile|dotfiles_target_user|dotfiles_target_home|dotfiles_target_source|dotfiles_target_connection)
                ;;
            *)
                log_error "Unsupported extra-vars key is not accepted: ${token_key}"
                exit 2
                ;;
        esac
        case "${token}" in
            dotfiles_target_profile=*)
                tuple_value="${token#dotfiles_target_profile=}"
                [[ -n "${tuple_value}" ]] || log_fatal "dotfiles_target_profile must be non-empty."
                [[ -z "${TUPLE_PROFILE}" ]] || log_fatal "Duplicate target profiles supplied."
                TUPLE_PROFILE="${tuple_value}"
                ;;
            dotfiles_target_user=*)
                EXTRA_VARS_USER="${token#dotfiles_target_user=}"
                record_selected_user "${EXTRA_VARS_USER}"
                [[ -z "${TUPLE_USER}" ]] || log_fatal "Duplicate target users supplied."
                TUPLE_USER="${EXTRA_VARS_USER}"
                ;;
            dotfiles_target_home=*)
                tuple_value="${token#dotfiles_target_home=}"
                [[ -n "${tuple_value}" ]] || log_fatal "dotfiles_target_home must be non-empty."
                [[ -z "${TUPLE_HOME}" ]] || log_fatal "Duplicate target homes supplied."
                TUPLE_HOME="${tuple_value}"
                ;;
            dotfiles_target_source=*)
                tuple_value="${token#dotfiles_target_source=}"
                [[ -n "${tuple_value}" ]] || log_fatal "dotfiles_target_source must be non-empty."
                [[ -z "${TUPLE_SOURCE}" ]] || log_fatal "Duplicate target sources supplied."
                TUPLE_SOURCE="${tuple_value}"
                ;;
            dotfiles_target_connection=*)
                tuple_value="${token#dotfiles_target_connection=}"
                [[ -n "${tuple_value}" ]] || log_fatal "dotfiles_target_connection must be non-empty."
                [[ -z "${TUPLE_CONNECTION}" ]] || log_fatal "Duplicate target connections supplied."
                TUPLE_CONNECTION="${tuple_value}"
                ;;
        esac
    done
}

# Parse arguments to extract --limit and the playbook path
while [[ $# -gt 0 ]]; do
    case "$1" in
        --limit)
            if [[ $# -lt 2 || -z "${2}" ]]; then
                log_error "--limit requires a non-empty target"
                exit 2
            fi
            if [[ "${LIMIT_SET}" == true ]]; then
                log_error "Duplicate --limit options are not allowed."
                exit 2
            fi
            LIMIT="${2:-}"
            LIMIT_SET=true
            PASSTHROUGH_ARGS+=("$1" "$2")
            shift 2
            ;;
        --limit=*)
            LIMIT="${1#--limit=}"
            if [[ -z "${LIMIT}" ]]; then
                log_error "--limit requires a non-empty target"
                exit 2
            fi
            if [[ "${LIMIT_SET}" == true ]]; then
                log_error "Duplicate --limit options are not allowed."
                exit 2
            fi
            LIMIT_SET=true
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
        --inventory|--inventory=*)
            log_error "Ansible inventory overrides are unsupported; the wrapper inventory is authoritative."
            exit 2
            ;;
        --connection)
            if [[ $# -lt 2 || -z "${2}" ]]; then
                log_error "--connection requires a value"
                exit 2
            fi
            REQUESTED_CONNECTION="${2}"
            EXPLICIT_CONNECTION=true
            shift 2
            ;;
        --connection=*)
            REQUESTED_CONNECTION="${1#--connection=}"
            if [[ -z "${REQUESTED_CONNECTION}" ]]; then
                log_error "--connection requires a non-empty value"
                exit 2
            fi
            EXPLICIT_CONNECTION=true
            shift
            ;;
        --user|--selected-user)
            if [[ $# -lt 2 || -z "${2}" ]]; then
                log_error "$1 requires a non-empty value"
                exit 2
            fi
            record_selected_user "${2}"
            shift 2
            ;;
        --user=*|--selected-user=*)
            record_selected_user "${1#*=}"
            shift
            ;;
        --extra-vars|-e)
            if [[ $# -lt 2 || -z "${2}" ]]; then
                log_error "$1 requires a value"
                exit 2
            fi
            extract_target_tuple "${2}"
            PASSTHROUGH_ARGS+=("$1" "$2")
            shift 2
            ;;
        --extra-vars=*)
            extra_vars="${1#--extra-vars=}"
            [[ -n "${extra_vars}" ]] || log_fatal "--extra-vars requires a value"
            extract_target_tuple "${extra_vars}"
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
        -e*)
            log_error "Attached -e forms are unsupported; use -e VALUE."
            exit 2
            ;;
        -l*)
            log_error "Short -l options are unsupported; use --limit VALUE."
            exit 2
            ;;
        -u*)
            log_error "Short -u options are unsupported; use --user VALUE for selected account binding."
            exit 2
            ;;
        -i*)
            log_error "Short -i options are unsupported; the wrapper inventory is authoritative."
            exit 2
            ;;
        -c=*)
            log_error "-c requires a separate value."
            exit 2
            ;;
        -c)
            if [[ $# -lt 2 || -z "${2}" ]]; then
                log_error "-c requires a value"
                exit 2
            fi
            REQUESTED_CONNECTION="${2}"
            EXPLICIT_CONNECTION=true
            shift 2
            ;;
        --syntax-check|--list-tasks)
            INSPECTION_ONLY=true
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
        --check|--diff)
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
        --*)
            log_error "Unsupported long option: $1"
            exit 2
            ;;
        -*)
            case "${1#-}" in
                *c*|*e*|*l*|*u*|*i*)
                    log_error "Short option clusters containing c, e, l, u, or i are unsupported."
                    ;;
                *)
                    log_error "Unsupported short option: $1"
                    ;;
            esac
            exit 2
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

if ! PLAYBOOK="$(canonicalize_playbook_path "${PLAYBOOK}")"; then
    exit 2
fi

[[ "${EXTRA_VARS_KV_PARSEABLE}" == true ]] || \
    log_fatal "Wrapper executions reject structured or indirect --extra-vars forms."

if [[ -z "${LIMIT}" && "${EXPLICIT_CONNECTION}" == true ]]; then
    log_fatal "Explicit connections require a --limit target."
fi

if [[ "${PLAYBOOK}" == "${SCRIPT_DIR}/playbooks/update.yml" ]]; then
    [[ "${LIMIT}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || \
        log_fatal "update.yml requires a literal safe inventory host name."
fi

if [[ "${PLAYBOOK}" == "${SCRIPT_DIR}/playbooks/site.yml" || "${PLAYBOOK}" == "${SCRIPT_DIR}/playbooks/update.yml" ]]; then
    [[ -n "${LIMIT}" ]] || log_fatal "site.yml requires a non-empty --limit target."
    [[ -n "${TUPLE_PROFILE}" ]] || log_fatal "site.yml requires dotfiles_target_profile in --extra-vars."
    [[ -n "${TUPLE_USER}" ]] || [[ -n "${SELECTED_USER}" ]] || \
        log_fatal "site.yml requires dotfiles_target_user in --extra-vars or --user."
    if [[ -z "${TUPLE_USER}" ]]; then
        TUPLE_USER="${SELECTED_USER}"
        PASSTHROUGH_ARGS+=(--extra-vars "dotfiles_target_user=${TUPLE_USER}")
    fi
    [[ -n "${TUPLE_HOME}" ]] || log_fatal "site.yml requires dotfiles_target_home in --extra-vars."
    [[ -n "${TUPLE_SOURCE}" ]] || log_fatal "site.yml requires dotfiles_target_source in --extra-vars."
    [[ -n "${TUPLE_CONNECTION}" ]] || log_fatal "site.yml requires dotfiles_target_connection in --extra-vars."
fi

INVENTORY_FILE="${DOTFILES_INVENTORY:-${SCRIPT_DIR}/inventory/hosts.yml}"

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
INVENTORY_JSON_CACHE=""

normalize_connection() {
    case "$1" in
        local)
            printf '%s' local
            ;;
        ssh|remote-ssh)
            printf '%s' ssh
            ;;
        *)
            return 1
            ;;
    esac
}

inventory_connection_from_json() {
    local inventory_json="$1"
    INVENTORY_JSON="${inventory_json}" \
        python3 "${REPO_ROOT}/scripts/lib/target-tuple.py" connection
}

inventory_connection_for_target() {
    local inventory_json
    inventory_json="$(inventory_json_for_target)" || return $?
    inventory_connection_from_json "${inventory_json}"
}

inventory_json_for_target() {
    local inventory_json
    if [[ -n "${INVENTORY_JSON_CACHE}" ]]; then
        printf '%s' "${INVENTORY_JSON_CACHE}"
        return 0
    fi
    command -v ansible-inventory >/dev/null 2>&1 || return 1
    command -v python3 >/dev/null 2>&1 || return 1
    inventory_json="$(ansible-inventory -i "${INVENTORY_FILE}" --host "${LIMIT}" 2>/dev/null)" || return 1
    [[ -n "${inventory_json}" ]] || return 2
    INVENTORY_JSON_CACHE="${inventory_json}"
    printf '%s' "${inventory_json}"
}

validate_site_inventory_tuple() {
    [[ "${PLAYBOOK}" == "${SCRIPT_DIR}/playbooks/site.yml" || "${PLAYBOOK}" == "${SCRIPT_DIR}/playbooks/update.yml" ]] || return 0

    local inventory_json
    inventory_json="$(inventory_json_for_target)" || \
        log_fatal "Unable to resolve inventory for site target '${LIMIT}'."

    INVENTORY_JSON="${inventory_json}" \
    TUPLE_PROFILE="${TUPLE_PROFILE}" \
    TUPLE_USER="${TUPLE_USER}" \
    TUPLE_HOME="${TUPLE_HOME}" \
    TUPLE_SOURCE="${TUPLE_SOURCE}" \
    TUPLE_CONNECTION="${TUPLE_CONNECTION}" \
        python3 "${REPO_ROOT}/scripts/lib/target-tuple.py" validate-site 2>&1
}

validate_connection_contract() {
    local expected_connection inventory_status=0
    if [[ -z "${LIMIT}" ]]; then
        return 0
    fi

    expected_connection="$(inventory_connection_for_target 2>/dev/null)" || inventory_status=$?
    if [[ "${inventory_status}" -ne 0 ]]; then
        log_fatal "Unable to resolve a valid inventory connection for target '${LIMIT}'."
    elif [[ -n "${REQUESTED_CONNECTION}" ]]; then
        REQUESTED_CONNECTION="$(normalize_connection "${REQUESTED_CONNECTION}")" || \
            log_fatal "Unsupported target connection: ${REQUESTED_CONNECTION}"
        [[ "${REQUESTED_CONNECTION}" == "${expected_connection}" ]] || \
            log_fatal "Target connection '${REQUESTED_CONNECTION}' does not match inventory connection '${expected_connection}'."
    else
        REQUESTED_CONNECTION="${expected_connection}"
    fi

    if [[ "${EXPLICIT_CONNECTION}" == true ]]; then
        CONNECTION_ARGS+=(--connection "${REQUESTED_CONNECTION}")
    else
        CONNECTION_ARGS+=(--connection="${REQUESTED_CONNECTION}")
    fi
    if [[ "${REQUESTED_CONNECTION}" == local ]]; then
        log_info "Using local connection for '${LIMIT}' (no SSH)"
    else
        log_info "Using SSH connection for '${LIMIT}'"
    fi
}

validate_site_inventory_tuple
validate_connection_contract

# SSH paths belong to the target filesystem, not the controller's namespace.
if [[ "${INSPECTION_ONLY}" == false && "${REQUESTED_CONNECTION}" == ssh && -n "${TUPLE_HOME}" && -n "${TUPLE_SOURCE}" ]]; then
    command -v ansible >/dev/null 2>&1 || log_fatal "ansible is required for target filesystem validation."
    printf -v target_check_args '%q check-paths %q %q' \
        "${REPO_ROOT}/scripts/lib/target-tuple.py" "${TUPLE_HOME}" "${TUPLE_SOURCE}"
    # The users role may not have created the selected account yet.
    ansible -i "${INVENTORY_FILE}" "${LIMIT}" --connection=ssh \
        --become --become-user root \
        --module-name ansible.builtin.script --args "${target_check_args} executable=python3"
fi

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------

ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK}" "${CONNECTION_ARGS[@]}" "${PASSTHROUGH_ARGS[@]}"
