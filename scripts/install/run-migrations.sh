#!/usr/bin/env bash
# Run dotfiles migrations (one-time scripts) with install-state tracking.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$REPO_ROOT" ]]; then
    # Fallback: scripts/install/ -> repo root is two dirs up
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/logging.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/install-state.sh"

MIGRATIONS_DIR="$REPO_ROOT/migrations"
LEGACY_MIGRATION_STATE_DIR="$HOME/.local/state/dotfiles/migrations"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--list] [--reset]

Options:
  --list   Show migration status and exit
  --reset  Clear install-state markers for migrations (update:migration:*)
EOF
}

reset_migration_state() {
    local state_dir="${STATE_DIR:-$HOME/.local/state/dotfiles/install}"
    rm -f "$state_dir"/update:migration:* 2>/dev/null || true
    log_success "Cleared migration install-state markers"
}

list_migrations() {
    if [[ ! -d "$MIGRATIONS_DIR" ]]; then
        log_info "No migrations directory found at: $MIGRATIONS_DIR"
        return 0
    fi

    log_info "Migrations directory: $MIGRATIONS_DIR"

    local f filename step_id
    while IFS= read -r f; do
        filename=$(basename "$f")
        step_id="update:migration:${filename}"
        if is_step_completed "$step_id"; then
            printf "%-35s %s\n" "$filename" "applied"
        else
            printf "%-35s %s\n" "$filename" "pending"
        fi
    done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name "*.sh" -print | sort)
}

main() {
    local do_list=false
    local do_reset=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --list) do_list=true; shift ;;
            --reset) do_reset=true; shift ;;
            -h|--help) usage; exit 0 ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [[ "$do_reset" == "true" ]]; then
        reset_migration_state
    fi

    if [[ "$do_list" == "true" ]]; then
        list_migrations
        return 0
    fi

    log_step "Running pending migrations..."

    if [[ ! -d "$MIGRATIONS_DIR" ]]; then
        log_info "No migrations directory found at: $MIGRATIONS_DIR"
        return 0
    fi

    if [[ -d "$LEGACY_MIGRATION_STATE_DIR" ]]; then
        log_info "Found legacy migration state dir; will import markers"
    fi

    local file filename step_id
    while IFS= read -r file; do
        filename=$(basename "$file")
        step_id="update:migration:${filename}"

        if is_step_completed "$step_id"; then
            log_info "Skipping migration (already applied): $filename"
            continue
        fi

        if [[ -f "${LEGACY_MIGRATION_STATE_DIR}/${filename}" ]]; then
            log_info "Importing legacy migration marker: $filename"
            mark_step_completed "$step_id"
            continue
        fi

        log_info "Running migration: $filename"
        chmod +x "$file"
        source "$file"
        mark_step_completed "$step_id"
    done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name "*.sh" -print | sort)

    log_success "Migrations complete"
}

main "$@"
