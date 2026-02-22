#!/usr/bin/env bash
#
# system-mods.sh - Safe, idempotent system file modification helpers
#
# Centralizes all /etc and system-level modifications behind a uniform API
# with automatic timestamped backups, content-based idempotency, and dry-run support.
#
# Environment:
#   SYSMOD_DRY_RUN=1   - Log actions without executing them
#   SYSMOD_BACKUP_ROOT  - Override backup directory (default: /etc/.dragonarchy-backups)
#
# Requires: logging.sh (log_info, log_success, log_warning, log_error)

SYSMOD_BACKUP_ROOT="${SYSMOD_BACKUP_ROOT:-/etc/.dragonarchy-backups}"

# Internal: run a command with sudo unless already root
_sysmod_sudo() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Internal: create a timestamped backup of a file before modifying it
_sysmod_backup() {
    local dest="$1"

    # Nothing to back up if the file doesn't exist
    [[ -e "$dest" ]] || return 0

    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    local backup_dir="${SYSMOD_BACKUP_ROOT}/${ts}"
    local rel="${dest#/}"
    local backup_path="${backup_dir}/${rel}"

    _sysmod_sudo mkdir -p "$(dirname "$backup_path")"
    _sysmod_sudo cp -a "$dest" "$backup_path"
    log_info "sysmod: backed up $dest -> $backup_path"
}

# Internal: compare two files by SHA-256
_sysmod_files_same() {
    local a="$1" b="$2"
    [[ -f "$a" && -f "$b" ]] || return 1
    local sum_a sum_b
    sum_a=$(sha256sum "$a" 2>/dev/null | cut -d' ' -f1)
    sum_b=$(sha256sum "$b" 2>/dev/null | cut -d' ' -f1)
    [[ -n "$sum_a" && -n "$sum_b" && "$sum_a" == "$sum_b" ]]
}

# ────────────────────────────────────────────────────────────────
# sysmod_install_file SRC DEST [MODE] [OWNER]
#
# Copy SRC to DEST with backup. Idempotent: skips if content matches.
# MODE defaults to preserving source permissions.
# OWNER is optional (e.g., "root:root").
# ────────────────────────────────────────────────────────────────
sysmod_install_file() {
    local src="$1" dest="$2" mode="${3:-}" owner="${4:-}"

    if [[ ! -f "$src" ]]; then
        log_error "sysmod_install_file: source not found: $src"
        return 1
    fi

    if _sysmod_files_same "$src" "$dest"; then
        log_info "sysmod: $dest already up to date (skipped)"
        return 1  # signal: no change
    fi

    if [[ "${SYSMOD_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] sysmod_install_file: $src -> $dest"
        return 0
    fi

    _sysmod_backup "$dest"
    _sysmod_sudo mkdir -p "$(dirname "$dest")"

    if [[ -n "$mode" ]]; then
        _sysmod_sudo install -m "$mode" "$src" "$dest"
    else
        _sysmod_sudo cp "$src" "$dest"
    fi

    if [[ -n "$owner" ]]; then
        _sysmod_sudo chown "$owner" "$dest"
    fi

    log_success "sysmod: installed $dest"
    return 0
}

# ────────────────────────────────────────────────────────────────
# sysmod_install_dir SRC DEST [OWNER]
#
# Recursively copy SRC directory to DEST with backup. Idempotent via rsync diff.
# ────────────────────────────────────────────────────────────────
sysmod_install_dir() {
    local src="$1" dest="$2" owner="${3:-}"

    if [[ ! -d "$src" ]]; then
        log_error "sysmod_install_dir: source directory not found: $src"
        return 1
    fi

    # Check for differences using rsync dry-run
    if [[ -d "$dest" ]]; then
        if ! rsync -rcn --out-format="%n" "${src}/" "${dest}/" 2>/dev/null | grep -q .; then
            log_info "sysmod: $dest already up to date (skipped)"
            return 1  # no change
        fi
    fi

    if [[ "${SYSMOD_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] sysmod_install_dir: $src -> $dest"
        return 0
    fi

    # Back up individual files that will be overwritten
    if [[ -d "$dest" ]]; then
        local changed_file
        while IFS= read -r changed_file; do
            [[ -z "$changed_file" ]] && continue
            local full="${dest}/${changed_file}"
            [[ -f "$full" ]] && _sysmod_backup "$full"
        done < <(rsync -rcn --out-format="%n" "${src}/" "${dest}/" 2>/dev/null)
    fi

    _sysmod_sudo cp -rT "$src" "$dest"

    if [[ -n "$owner" ]]; then
        _sysmod_sudo chown -R "$owner" "$dest"
    fi

    log_success "sysmod: installed directory $dest"
    return 0
}

# ────────────────────────────────────────────────────────────────
# sysmod_tee_file DEST CONTENT [MODE]
#
# Write CONTENT string to DEST. Idempotent: skips if content matches.
# ────────────────────────────────────────────────────────────────
sysmod_tee_file() {
    local dest="$1" content="$2" mode="${3:-644}"

    # Compare against existing content
    if [[ -f "$dest" ]]; then
        local existing
        existing=$(_sysmod_sudo cat "$dest" 2>/dev/null || true)
        if [[ "$existing" == "$content" ]]; then
            log_info "sysmod: $dest already has desired content (skipped)"
            return 1  # no change
        fi
    fi

    if [[ "${SYSMOD_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] sysmod_tee_file: $dest (${#content} bytes)"
        return 0
    fi

    _sysmod_backup "$dest"
    _sysmod_sudo mkdir -p "$(dirname "$dest")"
    printf '%s' "$content" | _sysmod_sudo tee "$dest" >/dev/null
    _sysmod_sudo chmod "$mode" "$dest"

    log_success "sysmod: wrote $dest"
    return 0
}

# ────────────────────────────────────────────────────────────────
# sysmod_append_if_missing FILE LINE
#
# Append LINE to FILE only if it doesn't already contain it.
# ────────────────────────────────────────────────────────────────
sysmod_append_if_missing() {
    local file="$1" line="$2"

    if [[ -f "$file" ]] && _sysmod_sudo grep -qFx "$line" "$file" 2>/dev/null; then
        log_info "sysmod: $file already contains line (skipped)"
        return 1  # no change
    fi

    if [[ "${SYSMOD_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] sysmod_append_if_missing: $file += '$line'"
        return 0
    fi

    _sysmod_backup "$file"
    _sysmod_sudo mkdir -p "$(dirname "$file")"
    printf '%s\n' "$line" | _sysmod_sudo tee -a "$file" >/dev/null

    log_success "sysmod: appended to $file"
    return 0
}

# ────────────────────────────────────────────────────────────────
# sysmod_ensure_service NAME [UNIT_FILE]
#
# Enable and start a systemd service. If UNIT_FILE is provided,
# install it first (idempotently). Handles daemon-reload.
# ────────────────────────────────────────────────────────────────
sysmod_ensure_service() {
    local name="$1" unit_file="${2:-}"

    if [[ "${SYSMOD_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] sysmod_ensure_service: $name"
        [[ -n "$unit_file" ]] && log_info "[dry-run]   unit file: $unit_file"
        return 0
    fi

    local needs_reload=false

    # Install unit file if provided
    if [[ -n "$unit_file" && -f "$unit_file" ]]; then
        if sysmod_install_file "$unit_file" "/etc/systemd/system/${name}"; then
            needs_reload=true
        fi
    fi

    if [[ "$needs_reload" == "true" ]]; then
        _sysmod_sudo systemctl daemon-reload
    fi

    # Enable if not already
    if ! systemctl is-enabled "$name" &>/dev/null; then
        _sysmod_sudo systemctl enable "$name"
        needs_reload=true
    fi

    # Start or restart
    if ! systemctl is-active "$name" &>/dev/null; then
        _sysmod_sudo systemctl start "$name"
    elif [[ "$needs_reload" == "true" ]]; then
        _sysmod_sudo systemctl restart "$name"
    fi

    log_success "sysmod: service $name enabled and running"
    return 0
}

# ────────────────────────────────────────────────────────────────
# sysmod_mask_service NAME
#
# Mask a systemd service idempotently.
# ────────────────────────────────────────────────────────────────
sysmod_mask_service() {
    local name="$1"

    # Check if already masked
    local state
    state=$(systemctl is-enabled "$name" 2>/dev/null || true)
    if [[ "$state" == "masked" ]]; then
        log_info "sysmod: service $name already masked (skipped)"
        return 1
    fi

    if [[ "${SYSMOD_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] sysmod_mask_service: $name"
        return 0
    fi

    _sysmod_sudo systemctl mask "$name" 2>/dev/null || true
    log_success "sysmod: masked service $name"
    return 0
}

# ────────────────────────────────────────────────────────────────
# sysmod_restart_if_running NAME
#
# Restart a systemd service only if it is currently active.
# Returns 0 if restarted, 1 if not running.
# ────────────────────────────────────────────────────────────────
sysmod_restart_if_running() {
    local name="$1"

    if ! systemctl is-active "${name}.service" &>/dev/null && \
       ! systemctl is-active "${name}" &>/dev/null; then
        return 1
    fi

    if [[ "${SYSMOD_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] sysmod_restart_if_running: $name"
        return 0
    fi

    _sysmod_sudo systemctl restart "$name"
    log_info "sysmod: restarted $name"
    return 0
}
