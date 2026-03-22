#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/logging.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/install-state.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/system-mods.sh"

SAMBA_CONF="/etc/samba/smb.conf"
USERSHARE_DIR="/var/lib/samba/usershares"
USERSHARE_GROUP="sambashare"
CURRENT_USER="${USER:-$(id -un)}"

desktop_smb_packages_installed() {
    is_package_installed "samba" || return 1
    is_package_installed "nemo-share" || return 1
    return 0
}

ensure_group_exists() {
    if getent group "$USERSHARE_GROUP" >/dev/null 2>&1; then
        log_info "Group '$USERSHARE_GROUP' already exists"
        return 0
    fi

    log_info "Creating Samba usershare group '$USERSHARE_GROUP'..."
    sudo groupadd --system "$USERSHARE_GROUP"
    log_success "Created group '$USERSHARE_GROUP'"
}

ensure_user_in_usershare_group() {
    local members
    members="$(getent group "$USERSHARE_GROUP" | awk -F: '{print $4}' 2>/dev/null || true)"
    if [[ ",${members}," == *",${CURRENT_USER},"* ]]; then
        log_info "User '${CURRENT_USER}' is already in '$USERSHARE_GROUP'"
        return 0
    fi

    log_info "Adding '${CURRENT_USER}' to '$USERSHARE_GROUP'..."
    sudo usermod -aG "$USERSHARE_GROUP" "$CURRENT_USER"
    log_success "Added '${CURRENT_USER}' to '$USERSHARE_GROUP'"
    log_warning "A new login session may be required before Samba usershare permissions apply"
}

ensure_usershare_dir() {
    log_info "Ensuring Samba usershare directory exists..."
    sudo install -d -m 1770 -o root -g "$USERSHARE_GROUP" "$USERSHARE_DIR"
    log_success "Samba usershare directory is ready"
}

set_samba_global_option() {
    local option="$1"
    local value="$2"
    local current rendered rc

    current="$(sudo cat "$SAMBA_CONF" 2>/dev/null || true)"
    if [[ -z "$current" ]]; then
        rendered=$'[global]\n'
        rendered+="${option} = ${value}"$'\n'
    else
        rendered="$(
            printf '%s\n' "$current" | awk -v option="$option" -v value="$value" '
                BEGIN {
                    in_global = 0
                    updated = 0
                }

                /^\[global\][[:space:]]*$/ {
                    in_global = 1
                    print
                    next
                }

                /^\[[^]]+\][[:space:]]*$/ {
                    if (in_global && !updated) {
                        printf("%s = %s\n", option, value)
                        updated = 1
                    }
                    in_global = 0
                    print
                    next
                }

                {
                    if (in_global && $0 ~ "^[[:space:]]*" option "[[:space:]]*=") {
                        if (!updated) {
                            printf("%s = %s\n", option, value)
                            updated = 1
                        }
                        next
                    }

                    print
                }

                END {
                    if (!updated) {
                        if (!in_global) {
                            print "[global]"
                        }
                        printf("%s = %s\n", option, value)
                    }
                }
            '
        )"
        rendered+=$'\n'
    fi

    rc=0
    sysmod_tee_file "$SAMBA_CONF" "$rendered" 644 >/dev/null || rc=$?
    case "$rc" in
        0|1)
            return "$rc"
            ;;
        *)
            log_error "Failed to update Samba global option '${option}'"
            return 2
            ;;
    esac
}

configure_samba_usershare() {
    local changed=0
    local rc=0

    set_samba_global_option "usershare path" "$USERSHARE_DIR" || rc=$?
    case "$rc" in
        0) ;;
        1) changed=1 ;;
        *) return 2 ;;
    esac
    rc=0

    set_samba_global_option "usershare max shares" "100" || rc=$?
    case "$rc" in
        0) ;;
        1) changed=1 ;;
        *) return 2 ;;
    esac
    rc=0

    set_samba_global_option "usershare allow guests" "yes" || rc=$?
    case "$rc" in
        0) ;;
        1) changed=1 ;;
        *) return 2 ;;
    esac
    rc=0

    set_samba_global_option "usershare owner only" "true" || rc=$?
    case "$rc" in
        0) ;;
        1) changed=1 ;;
        *) return 2 ;;
    esac

    if [[ "$changed" -eq 1 ]]; then
        log_success "Samba usershare configuration updated"
    else
        log_info "Samba usershare configuration already up to date"
    fi
}

ensure_samba_service() {
    if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^smbd\.service'; then
        sysmod_ensure_service "smbd.service" >/dev/null || true
        sysmod_restart_if_running "smbd.service" >/dev/null || true
        log_success "smbd service is enabled"
    else
        log_warning "smbd.service is not available; Samba usershare will need manual service management"
    fi
}

main() {
    if ! desktop_smb_packages_installed; then
        log_info "desktop_smb packages are not installed; skipping Samba usershare setup"
        exit 0
    fi

    if [[ ! -f "$SAMBA_CONF" ]]; then
        log_warning "Samba configuration file '${SAMBA_CONF}' is missing; skipping usershare setup"
        exit 0
    fi

    log_info "Configuring Samba usershare prerequisites..."
    ensure_group_exists
    ensure_user_in_usershare_group
    ensure_usershare_dir
    configure_samba_usershare
    ensure_samba_service
    log_success "Samba usershare setup completed"
}

main "$@"
