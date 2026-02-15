#!/usr/bin/env bash
# Run dotfiles migrations (one-time scripts) with install-state tracking.
#
# Features:
#   - State tracking via install-state.sh (idempotent)
#   - Dry-run mode (preview without applying)
#   - Rollback support (companion .rollback.sh files)
#   - Dependency management (# Depends: <migration-filename> headers)
#   - Migration history reporting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$REPO_ROOT" ]]; then
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/logging.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/install-state.sh"

MIGRATIONS_DIR="$REPO_ROOT/migrations"
LEGACY_MIGRATION_STATE_DIR="$HOME/.local/state/dotfiles/migrations"
HISTORY_DIR="$HOME/.local/state/dotfiles/migration-history"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run pending dotfiles migrations with state tracking.

Options:
  --list          Show migration status and exit
  --dry-run       Preview which migrations would run (no changes applied)
  --rollback FILE Rollback a specific migration (runs its .rollback.sh companion)
  --report        Generate a migration history report
  --reset         Clear install-state markers for migrations (update:migration:*)
  -h, --help      Show this help message

Migration Metadata:
  Migrations can declare dependencies via comment headers:
    # Depends: 20260111_0001_fontconfig-path-and-stow-safe-theme.sh
  Dependent migrations will run after their dependencies.

Rollback:
  Each migration can have a companion rollback file:
    migrations/20260111_0001_some-migration.sh
    migrations/20260111_0001_some-migration.rollback.sh
  Use --rollback <filename> to execute the rollback script.

EOF
}

# --- Dependency Resolution ---

# Extract dependency filenames from a migration file's header comments.
# Format: # Depends: <filename>
# Multiple dependencies are supported (one per line).
parse_dependencies() {
    local migration_file="$1"
    local deps=()
    local line
    while IFS= read -r line; do
        # Stop parsing after the first non-comment, non-blank line
        if [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi
        if [[ ! "$line" =~ ^[[:space:]]*# ]]; then
            break
        fi
        # Match: # Depends: <filename>
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*[Dd]epends:[[:space:]]*(.+)$ ]]; then
            local dep="${BASH_REMATCH[1]}"
            dep="${dep## }"
            dep="${dep%% }"
            deps+=("$dep")
        fi
    done < "$migration_file"
    printf '%s\n' "${deps[@]}"
}

# Build a topologically sorted list of migrations respecting dependencies.
# Returns a newline-separated list of migration file paths in execution order.
resolve_migration_order() {
    local -a all_files=()
    while IFS= read -r f; do
        all_files+=("$f")
    done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name "*.sh" ! -name "*.rollback.sh" -print | sort)

    if [[ ${#all_files[@]} -eq 0 ]]; then
        return 0
    fi

    # Build adjacency map: filename -> space-separated dependency filenames
    declare -A dep_map=()
    declare -A file_map=()
    local f filename
    for f in "${all_files[@]}"; do
        filename="$(basename "$f")"
        file_map["$filename"]="$f"
        local deps_str=""
        while IFS= read -r dep; do
            [[ -z "$dep" ]] && continue
            deps_str+="$dep "
        done < <(parse_dependencies "$f")
        dep_map["$filename"]="${deps_str}"
    done

    # Kahn's algorithm for topological sort
    declare -A in_degree=()
    for filename in "${!file_map[@]}"; do
        in_degree["$filename"]=0
    done

    local dep
    for filename in "${!dep_map[@]}"; do
        for dep in ${dep_map["$filename"]}; do
            if [[ -n "${file_map[$dep]:-}" ]]; then
                in_degree["$filename"]=$(( ${in_degree["$filename"]} + 1 ))
            else
                log_warning "Migration '$filename' depends on '$dep' which does not exist; ignoring dependency"
            fi
        done
    done

    local -a queue=()
    for filename in "${!in_degree[@]}"; do
        if [[ ${in_degree["$filename"]} -eq 0 ]]; then
            queue+=("$filename")
        fi
    done

    # Sort the zero-in-degree set for deterministic order
    IFS=$'\n' read -r -d '' -a queue < <(printf '%s\n' "${queue[@]}" | sort; printf '\0') || true

    local -a sorted=()
    while [[ ${#queue[@]} -gt 0 ]]; do
        local current="${queue[0]}"
        queue=("${queue[@]:1}")
        sorted+=("$current")

        # Reduce in-degree for dependents
        for filename in "${!dep_map[@]}"; do
            for dep in ${dep_map["$filename"]}; do
                if [[ "$dep" == "$current" ]]; then
                    in_degree["$filename"]=$(( ${in_degree["$filename"]} - 1 ))
                    if [[ ${in_degree["$filename"]} -eq 0 ]]; then
                        queue+=("$filename")
                    fi
                fi
            done
        done
        # Re-sort queue for determinism
        if [[ ${#queue[@]} -gt 1 ]]; then
            IFS=$'\n' read -r -d '' -a queue < <(printf '%s\n' "${queue[@]}" | sort; printf '\0') || true
        fi
    done

    # Check for cycles
    if [[ ${#sorted[@]} -ne ${#all_files[@]} ]]; then
        log_error "Dependency cycle detected in migrations! The following migrations have unresolvable dependencies:"
        for filename in "${!in_degree[@]}"; do
            if [[ ${in_degree["$filename"]} -gt 0 ]]; then
                log_error "  $filename (depends on: ${dep_map[$filename]})"
            fi
        done
        return 1
    fi

    for filename in "${sorted[@]}"; do
        echo "${file_map[$filename]}"
    done
}

# --- State Management ---

reset_migration_state() {
    local state_dir="${STATE_DIR:-$HOME/.local/state/dotfiles/install}"
    rm -f "$state_dir"/update:migration:* 2>/dev/null || true
    log_success "Cleared migration install-state markers"
}

# --- Listing ---

list_migrations() {
    if [[ ! -d "$MIGRATIONS_DIR" ]]; then
        log_info "No migrations directory found at: $MIGRATIONS_DIR"
        return 0
    fi

    log_info "Migrations directory: $MIGRATIONS_DIR"
    echo

    printf "%-50s %-10s %s\n" "MIGRATION" "STATUS" "DEPENDENCIES"
    printf "%-50s %-10s %s\n" "---------" "------" "------------"

    local f filename step_id
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        filename=$(basename "$f")
        step_id="update:migration:${filename}"

        local status="pending"
        if is_step_completed "$step_id"; then
            status="applied"
        fi

        local deps=""
        while IFS= read -r dep; do
            [[ -z "$dep" ]] && continue
            if [[ -n "$deps" ]]; then
                deps+=", $dep"
            else
                deps="$dep"
            fi
        done < <(parse_dependencies "$f")

        local rollback_indicator=""
        if [[ -f "${f%.sh}.rollback.sh" ]]; then
            rollback_indicator=" [rollback available]"
        fi

        printf "%-50s %-10s %s%s\n" "$filename" "$status" "${deps:-none}" "$rollback_indicator"
    done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name "*.sh" ! -name "*.rollback.sh" -print | sort)
}

# --- Dry Run ---

dry_run_migrations() {
    if [[ ! -d "$MIGRATIONS_DIR" ]]; then
        log_info "No migrations directory found at: $MIGRATIONS_DIR"
        return 0
    fi

    log_step "Dry run: previewing pending migrations..."
    echo

    local pending_count=0
    local skip_count=0

    local file filename step_id
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        filename=$(basename "$file")
        step_id="update:migration:${filename}"

        if is_step_completed "$step_id"; then
            skip_count=$((skip_count + 1))
            continue
        fi

        if [[ -f "${LEGACY_MIGRATION_STATE_DIR}/${filename}" ]]; then
            log_info "[DRY RUN] Would import legacy marker: $filename"
            skip_count=$((skip_count + 1))
            continue
        fi

        pending_count=$((pending_count + 1))
        log_info "[DRY RUN] Would run: $filename"

        # Show dependencies
        local deps=""
        while IFS= read -r dep; do
            [[ -z "$dep" ]] && continue
            deps+="  depends on: $dep"$'\n'
        done < <(parse_dependencies "$file")
        if [[ -n "$deps" ]]; then
            printf '%s' "$deps"
        fi

        # Show first comment block as description
        local desc_line
        while IFS= read -r desc_line; do
            [[ "$desc_line" =~ ^[[:space:]]*$ ]] && continue
            [[ ! "$desc_line" =~ ^[[:space:]]*# ]] && break
            [[ "$desc_line" =~ ^#!/ ]] && continue
            [[ "$desc_line" =~ [Dd]epends: ]] && continue
            echo "  ${desc_line#"${desc_line%%[! ]*}"}"
        done < "$file"
        echo
    done < <(resolve_migration_order)

    echo
    log_info "Summary: $pending_count pending, $skip_count already applied"

    if [[ $pending_count -eq 0 ]]; then
        log_success "No pending migrations to run"
    else
        log_info "Run without --dry-run to apply these migrations"
    fi
}

# --- Rollback ---

rollback_migration() {
    local target_filename="$1"

    # Normalize: strip path if full path given
    target_filename="$(basename "$target_filename")"

    # Ensure it ends in .sh
    if [[ "$target_filename" != *.sh ]]; then
        target_filename="${target_filename}.sh"
    fi

    local rollback_file="$MIGRATIONS_DIR/${target_filename%.sh}.rollback.sh"

    if [[ ! -f "$rollback_file" ]]; then
        log_error "No rollback script found for '$target_filename'"
        log_info "Expected: $rollback_file"
        log_info "Create a rollback script to enable this feature."
        return 1
    fi

    local step_id="update:migration:${target_filename}"

    if ! is_step_completed "$step_id"; then
        log_warning "Migration '$target_filename' was not applied; rollback may have no effect"
    fi

    log_step "Rolling back migration: $target_filename"
    chmod +x "$rollback_file"
    source "$rollback_file"

    # Remove the completion marker
    reset_step "$step_id"

    # Record rollback in history
    record_history "rollback" "$target_filename"

    log_success "Rollback complete for: $target_filename"
}

# --- History Recording & Reporting ---

record_history() {
    local action="$1"
    local filename="$2"
    mkdir -p "$HISTORY_DIR"
    printf '%s %s %s\n' "$(date --iso-8601=seconds)" "$action" "$filename" >> "$HISTORY_DIR/migration.log"
}

generate_report() {
    log_step "Migration History Report"
    echo

    # Current state
    log_info "=== Current Migration State ==="
    list_migrations
    echo

    # History log
    log_info "=== Migration History Log ==="
    if [[ -f "$HISTORY_DIR/migration.log" ]]; then
        printf "%-30s %-10s %s\n" "TIMESTAMP" "ACTION" "MIGRATION"
        printf "%-30s %-10s %s\n" "---------" "------" "---------"
        while IFS=' ' read -r ts action filename rest; do
            printf "%-30s %-10s %s\n" "$ts" "$action" "$filename"
        done < "$HISTORY_DIR/migration.log"
    else
        log_info "No migration history recorded yet"
    fi
    echo

    # Statistics
    local total=0 applied=0 pending=0 with_rollback=0
    if [[ -d "$MIGRATIONS_DIR" ]]; then
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            total=$((total + 1))
            local fn step_id
            fn="$(basename "$f")"
            step_id="update:migration:${fn}"
            if is_step_completed "$step_id"; then
                applied=$((applied + 1))
            else
                pending=$((pending + 1))
            fi
            if [[ -f "${f%.sh}.rollback.sh" ]]; then
                with_rollback=$((with_rollback + 1))
            fi
        done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name "*.sh" ! -name "*.rollback.sh" -print | sort)
    fi

    log_info "=== Statistics ==="
    log_info "  Total migrations:       $total"
    log_info "  Applied:                $applied"
    log_info "  Pending:                $pending"
    log_info "  With rollback support:  $with_rollback"
}

# --- Main Runner ---

run_migrations() {
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
        [[ -z "$file" ]] && continue
        filename=$(basename "$file")
        step_id="update:migration:${filename}"

        if is_step_completed "$step_id"; then
            log_info "Skipping migration (already applied): $filename"
            continue
        fi

        if [[ -f "${LEGACY_MIGRATION_STATE_DIR}/${filename}" ]]; then
            log_info "Importing legacy migration marker: $filename"
            mark_step_completed "$step_id"
            record_history "import-legacy" "$filename"
            continue
        fi

        log_info "Running migration: $filename"
        chmod +x "$file"
        source "$file"
        mark_step_completed "$step_id"
        record_history "applied" "$filename"
    done < <(resolve_migration_order)

    log_success "Migrations complete"
}

# --- Entry Point ---

main() {
    local do_list=false
    local do_reset=false
    local do_dry_run=false
    local do_rollback=""
    local do_report=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --list) do_list=true; shift ;;
            --reset) do_reset=true; shift ;;
            --dry-run) do_dry_run=true; shift ;;
            --rollback)
                do_rollback="${2:-}"
                if [[ -z "$do_rollback" ]]; then
                    log_error "--rollback requires a migration filename argument"
                    usage
                    exit 1
                fi
                shift 2
                ;;
            --report) do_report=true; shift ;;
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

    if [[ "$do_report" == "true" ]]; then
        generate_report
        return 0
    fi

    if [[ "$do_list" == "true" ]]; then
        list_migrations
        return 0
    fi

    if [[ -n "$do_rollback" ]]; then
        rollback_migration "$do_rollback"
        return 0
    fi

    if [[ "$do_dry_run" == "true" ]]; then
        dry_run_migrations
        return 0
    fi

    run_migrations
}

main "$@"
