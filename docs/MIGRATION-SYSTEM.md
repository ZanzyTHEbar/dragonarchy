# Dotfiles Migration System

## Overview

This repository includes a lightweight migration system for managing one-time setup tasks, database schema changes, configuration updates, or any other sequential operations that should be executed once and tracked.

## Purpose

The migration system allows you to:
- Create timestamped migration scripts
- Track which migrations have been applied
- Apply migrations in chronological order
- Manage one-time configuration changes across different hosts
- Document changes to the dotfiles over time

## Directory Structure

```
dotfiles/
├── migrations/              # Migration scripts directory
│   ├── 1699564800.sh       # Example: timestamp-based migration
│   ├── 1699651200.sh       # Migrations run in chronological order
│   └── README.md           # Migration-specific documentation
└── scripts/
    └── utilities/
        └── add-migration.sh # Tool to create new migrations
```

## How It Works

### Creating a Migration

Use the `add-migration.sh` script to create a new migration:

```bash
./scripts/utilities/add-migration.sh
```

This will:
1. Create a new migration file in `migrations/` with a Unix timestamp filename
2. Add boilerplate code to the migration file
3. Open the file in your editor (respects `$EDITOR` environment variable)

### Migration File Structure

Each migration file is a standalone bash script:

```bash
#!/bin/bash

set -e

echo "Running migration 1699564800.sh"

# Your migration code here
```

### What Can Migrations Do?

Migrations are full bash scripts and can perform any operation:

- **Package Installation**: Install new packages or dependencies
- **Configuration Changes**: Update config files, add new settings
- **Directory Setup**: Create new directories, move files
- **Service Configuration**: Enable/disable systemd services
- **Cleanup**: Remove deprecated files or configurations
- **Database Operations**: Update local databases (if applicable)
- **One-Time Tasks**: Any task that should run once per system

### Example Migrations

#### Example 1: Add New Package

```bash
#!/bin/bash
set -e

echo "Running migration $(basename "$0"): Install ripgrep"

# Add centralized logging if needed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../scripts/lib/logging.sh"

log_info "Installing ripgrep for faster searching"

if command -v yay &>/dev/null; then
    yay -S --noconfirm ripgrep
    log_success "ripgrep installed"
else
    log_error "yay not found, please install ripgrep manually"
    exit 1
fi
```

#### Example 2: Update Configuration

```bash
#!/bin/bash
set -e

echo "Running migration $(basename "$0"): Enable new Hyprland feature"

CONFIG_FILE="$HOME/.config/hypr/hyprland.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    # Add new configuration line if it doesn't exist
    if ! grep -q "new_feature = true" "$CONFIG_FILE"; then
        echo "new_feature = true" >> "$CONFIG_FILE"
        echo "✓ Added new feature to Hyprland config"
    else
        echo "✓ Feature already enabled"
    fi
else
    echo "⚠ Config file not found: $CONFIG_FILE"
fi
```

#### Example 3: Directory Restructure

```bash
#!/bin/bash
set -e

echo "Running migration $(basename "$0"): Reorganize theme files"

OLD_DIR="$HOME/.config/themes"
NEW_DIR="$HOME/.local/share/themes"

if [[ -d "$OLD_DIR" ]] && [[ ! -d "$NEW_DIR" ]]; then
    mkdir -p "$(dirname "$NEW_DIR")"
    mv "$OLD_DIR" "$NEW_DIR"
    echo "✓ Moved themes from $OLD_DIR to $NEW_DIR"
elif [[ -d "$NEW_DIR" ]]; then
    echo "✓ Themes already in new location"
else
    echo "⚠ No themes directory found"
fi
```

## Running Migrations

### Recommended: Run via Helper Script

Use the migration runner, which applies install-state step IDs like `update:migration:<filename>` and also imports any legacy markers automatically:

```bash
./scripts/install/run-migrations.sh
./scripts/install/run-migrations.sh --list
./scripts/install/run-migrations.sh --reset
```

### Also Supported: Run via System Update

The updater also runs pending migrations:

```bash
./scripts/install/update.sh
```

### Manual Execution

Migrations are standalone scripts and can be run individually:

```bash
# Run a specific migration
./migrations/1699564800.sh

# Run all migrations in order
for migration in migrations/*.sh; do
    bash "$migration"
done
```

### Integration with Setup Scripts

To integrate migrations into your setup process, add to `setup.sh`:

```bash
run_migrations() {
    local migrations_dir="$SCRIPT_DIR/migrations"
    
    if [[ ! -d "$migrations_dir" ]]; then
        log_info "No migrations directory found"
        return 0
    fi
    
    log_step "Running migrations..."
    
    for migration in "$migrations_dir"/*.sh; do
        if [[ -f "$migration" ]]; then
            log_info "Running: $(basename "$migration")"
            if bash "$migration"; then
                log_success "Migration completed: $(basename "$migration")"
            else
                log_error "Migration failed: $(basename "$migration")"
                return 1
            fi
        fi
    done
    
    log_success "All migrations completed"
}
```

### Tracking Applied Migrations

For consistent tracking across the repo, prefer using the shared install-state library. This is what the updater uses.

Applied migrations are recorded under:
- `~/.local/state/dotfiles/install/`

With step IDs like:
- `update:migration:<filename>`

Example helper:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../scripts/lib/logging.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../scripts/lib/install-state.sh"

run_migration_if_needed() {
    local migration="$1"
    local filename
    filename=$(basename "$migration")
    local step_id="update:migration:${filename}"

    if is_step_completed "$step_id"; then
        log_info "Skipping (already applied): $filename"
        return 0
    fi

    log_info "Running: $filename"
    bash "$migration"
    mark_step_completed "$step_id"
}
```

Note: older versions used legacy markers under `~/.local/state/dotfiles/migrations/`. The current updater imports those markers to avoid re-running already-applied migrations.

## Best Practices

### 1. Make Migrations Idempotent

Migrations should be safe to run multiple times:

```bash
# BAD: Will fail on second run
mkdir ~/.config/new-app

# GOOD: Check first
if [[ ! -d ~/.config/new-app ]]; then
    mkdir ~/.config/new-app
fi
```

### 2. Use Descriptive Comments

Add a comment at the top explaining what the migration does:

```bash
#!/bin/bash
# Migration: Add support for Wayland screensharing
# Date: 2024-11-08
# Author: DevOps Team
# Purpose: Install and configure xdg-desktop-portal-hyprland

set -e
# ... migration code
```

### 3. Test Before Committing

Always test migrations on a clean system or VM before committing.

### 4. Handle Errors Gracefully

```bash
#!/bin/bash
set -e  # Exit on error

# But handle expected failures
if ! command -v some-tool &>/dev/null; then
    echo "Warning: some-tool not found, skipping this migration"
    exit 0  # Exit successfully
fi
```

### 5. Document Breaking Changes

If a migration makes breaking changes, document them:

```bash
#!/bin/bash
# BREAKING CHANGE: This migration removes old config format
# Backup your ~/.config/app/config.json before running
```

### 6. Use Centralized Logging

Integrate with the dotfiles logging system:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../scripts/lib/logging.sh"

log_info "Starting migration: $(basename "$0")"
# ... use log_info, log_success, log_error, etc.
```

## Integration with Dotfiles

### When to Use Migrations

Use migrations for:
- ✅ One-time configuration changes
- ✅ Package additions/removals
- ✅ Directory structure changes
- ✅ Service configuration updates
- ✅ Cleanup of deprecated files

Don't use migrations for:
- ❌ Regular package updates (use update scripts)
- ❌ Configuration changes that should be managed by stow
- ❌ Temporary changes or experiments

### Migration vs. Setup Scripts

| Aspect | Migrations | Setup Scripts |
|--------|-----------|---------------|
| **Purpose** | One-time changes | Repeatable setup |
| **Frequency** | Once per system | Can run multiple times |
| **Tracking** | Timestamped | Not tracked |
| **Idempotency** | Should be idempotent | Must be idempotent |
| **Use Case** | Evolving config | Initial setup |

## Workflow Example

1. **Make a dotfiles change** that requires a one-time update:
   ```bash
   # Edit some config
   vim packages/hyprland/.config/hypr/hyprland.conf
   ```

2. **Create a migration** for existing users:
   ```bash
   ./scripts/utilities/add-migration.sh
   ```

3. **Write the migration** to update existing systems:
   ```bash
   # In the editor that opens:
   #!/bin/bash
   set -e
   echo "Updating Hyprland config..."
   # Copy new config or add new lines
   ```

4. **Test the migration**:
   ```bash
   bash migrations/1699564800.sh
   ```

5. **Commit both changes**:
   ```bash
   git add packages/hyprland/.config/hypr/hyprland.conf
   git add migrations/1699564800.sh
   git commit -m "feat(hyprland): add new feature with migration"
   ```

6. **Document in README or CHANGELOG**:
   ```markdown
   ## Update Instructions
   
   After pulling, run: `./migrations/1699564800.sh`
   ```

## Future Enhancements

Potential improvements to the migration system:

- [ ] **Migration Runner**: Create `run-migrations.sh` script
- [ ] **State Tracking**: Track applied migrations in `~/.config/dotfiles/`
- [ ] **Rollback Support**: Add reverse migrations
- [ ] **Dry Run Mode**: Preview changes before applying
- [ ] **Dependency Management**: Allow migrations to depend on others
- [ ] **Integration**: Automatic migration check in `setup.sh`
- [ ] **Reporting**: Generate migration history reports

## Related Files

- `scripts/utilities/add-migration.sh` - Migration creator tool
- `scripts/lib/logging.sh` - Centralized logging for migrations
- `setup.sh` - Main setup script (can integrate migrations)

## See Also

- Database migration systems (Flyway, Liquibase) for inspiration
- [Git hooks documentation](https://git-scm.com/docs/githooks)
- [Bash scripting best practices](https://google.github.io/styleguide/shellguide.html)

