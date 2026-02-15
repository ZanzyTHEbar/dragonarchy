#!/bin/bash
# Create a new migration file with boilerplate, optional rollback companion,
# and dependency metadata support.

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
MIGRATIONS_DIR="$REPO_ROOT/migrations"

mkdir -p "$MIGRATIONS_DIR"

# Generate a descriptive filename: YYYYMMDD_NNNN_<slug>.sh
today=$(date +%Y%m%d)

# Find the next sequence number for today
seq_num=1
while true; do
    prefix=$(printf "%s_%04d" "$today" "$seq_num")
    if ! ls "$MIGRATIONS_DIR/${prefix}_"*.sh >/dev/null 2>&1; then
        break
    fi
    seq_num=$((seq_num + 1))
done

# Get description from user
description=""
if [[ -n "${1:-}" ]]; then
    description="$1"
elif [[ -t 0 ]] && command -v gum >/dev/null 2>&1; then
    description=$(gum input --placeholder "Short description (e.g., fix-stow-conflicts-kitty)" --header="Migration description (kebab-case)")
elif [[ -t 0 ]]; then
    printf "Short description (kebab-case, e.g., fix-stow-conflicts-kitty): "
    read -r description
fi

if [[ -z "$description" ]]; then
    description="unnamed-migration"
fi

# Sanitize to kebab-case
slug=$(echo "$description" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | tr -cd 'a-z0-9-')

migration_name=$(printf "%s_%04d_%s.sh" "$today" "$seq_num" "$slug")
migration_file="$MIGRATIONS_DIR/$migration_name"

# Ask about rollback support
create_rollback=false
if [[ -t 0 ]] && command -v gum >/dev/null 2>&1; then
    if gum confirm "Create a rollback companion script?"; then
        create_rollback=true
    fi
elif [[ -t 0 ]]; then
    printf "Create a rollback companion script? [y/N]: "
    read -r answer
    if [[ "$answer" =~ ^[Yy] ]]; then
        create_rollback=true
    fi
fi

# Ask about dependencies
depends_on=""
if [[ -t 0 ]]; then
    existing_migrations=()
    while IFS= read -r f; do
        existing_migrations+=("$(basename "$f")")
    done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name "*.sh" ! -name "*.rollback.sh" -print | sort)

    if [[ ${#existing_migrations[@]} -gt 0 ]]; then
        if command -v gum >/dev/null 2>&1; then
            if gum confirm "Does this migration depend on any existing migration?"; then
                depends_on=$(printf '%s\n' "${existing_migrations[@]}" | gum choose --no-limit --header="Select dependencies (space to select, enter to confirm)") || true
            fi
        fi
    fi
fi

# Build dependency header
dep_header=""
if [[ -n "$depends_on" ]]; then
    while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue
        dep_header+="# Depends: $dep"$'\n'
    done <<< "$depends_on"
fi

# Create the migration file
cat > "$migration_file" <<MIGRATION_EOF
#!/usr/bin/env bash
# Migration: $description
# Date: $(date +%Y-%m-%d)
# Author: $(git config user.name 2>/dev/null || echo "unknown")
${dep_header}#
# Purpose: <describe what this migration does and why>

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="\$(git -C "\$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "\$REPO_ROOT" ]]; then
  REPO_ROOT="\$(cd "\$SCRIPT_DIR/.." && pwd)"
fi

# shellcheck disable=SC1091
source "\$REPO_ROOT/scripts/lib/logging.sh"

log_info "Migration \$(basename "\$0"): $description"

# Your migration code here


log_success "Migration complete"
MIGRATION_EOF

chmod +x "$migration_file"

echo "Created new migration: $migration_file"

# Create rollback companion if requested
if [[ "$create_rollback" == "true" ]]; then
    rollback_file="${migration_file%.sh}.rollback.sh"
    cat > "$rollback_file" <<ROLLBACK_EOF
#!/usr/bin/env bash
# Rollback for: $migration_name
# Reverses the changes made by the migration.
#
# Run via: ./scripts/install/run-migrations.sh --rollback $migration_name

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="\$(git -C "\$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "\$REPO_ROOT" ]]; then
  REPO_ROOT="\$(cd "\$SCRIPT_DIR/.." && pwd)"
fi

# shellcheck disable=SC1091
source "\$REPO_ROOT/scripts/lib/logging.sh"

log_info "Rolling back: \$(basename "\${BASH_SOURCE[0]%.rollback.sh}.sh")"

# Your rollback code here (reverse the migration changes)


log_success "Rollback complete"
ROLLBACK_EOF

    chmod +x "$rollback_file"
    echo "Created rollback companion: $rollback_file"
fi

echo
echo "Run migrations with:"
echo "  ./scripts/install/run-migrations.sh"
echo "Preview with dry run:"
echo "  ./scripts/install/run-migrations.sh --dry-run"
echo "Or as part of a full update:"
echo "  ./scripts/install/update.sh"

# Open the new migration file in the user's editor
if [[ -n "${EDITOR:-}" ]]; then
    "$EDITOR" "$migration_file"
elif command -v nvim &>/dev/null; then
    nvim "$migration_file"
elif command -v code &>/dev/null; then
    code --wait "$migration_file"
else
    vi "$migration_file"
fi
