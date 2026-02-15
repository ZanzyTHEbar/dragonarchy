# Dotfiles Migration System

## Overview

This repository includes a lightweight migration system for managing one-time setup tasks, configuration updates, or any other sequential operations that should be executed once and tracked.

## Purpose

The migration system allows you to:
- Create timestamped migration scripts with descriptive names
- Track which migrations have been applied (via `install-state.sh`)
- Apply migrations in chronological order with dependency resolution
- Preview changes with dry-run mode before applying
- Roll back migrations using companion rollback scripts
- Generate migration history reports
- Manage one-time configuration changes across different hosts

## Directory Structure

```
dotfiles/
├── migrations/                          # Migration scripts directory
│   ├── 20260111_0001_some-migration.sh          # Migration script
│   ├── 20260111_0001_some-migration.rollback.sh # Optional rollback companion
│   ├── 20260111_0002_another-change.sh          # Migrations run in dependency/chronological order
│   └── ...
└── scripts/
    ├── install/
    │   └── run-migrations.sh            # Migration runner with full feature set
    ├── lib/
    │   ├── install-state.sh             # State tracking library
    │   └── logging.sh                   # Centralized logging
    └── utilities/
        └── add-migration.sh             # Tool to create new migrations
```

## How It Works

### Creating a Migration

Use the `add-migration.sh` script to create a new migration:

```bash
./scripts/utilities/add-migration.sh
# or with a description:
./scripts/utilities/add-migration.sh "fix-stow-conflicts"
```

This will:
1. Create a new migration file in `migrations/` with a descriptive filename (e.g., `20260215_0001_fix-stow-conflicts.sh`)
2. Optionally create a rollback companion script
3. Optionally set dependencies on existing migrations
4. Add boilerplate code including logging integration
5. Open the file in your editor (respects `$EDITOR` environment variable)

### Migration File Structure

Each migration file is a standalone bash script with metadata headers:

```bash
#!/usr/bin/env bash
# Migration: fix stow conflicts for kitty
# Date: 2026-02-15
# Author: Your Name
# Depends: 20260111_0001_fontconfig-path-and-stow-safe-theme.sh
#
# Purpose: Clean up replaced stow symlinks that cause conflicts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/logging.sh"

log_info "Migration $(basename "$0"): fix stow conflicts for kitty"

# Your migration code here

log_success "Migration complete"
```

### Dependency Management

Migrations can declare dependencies on other migrations using comment headers:

```bash
#!/usr/bin/env bash
# Migration: enable new feature
# Depends: 20260111_0001_fontconfig-path-and-stow-safe-theme.sh
# Depends: 20260111_0002_fix-stow-conflicts-kitty-walker.sh
```

The migration runner performs topological sorting to ensure dependencies run first. Circular dependencies are detected and reported as errors.

### Rollback Support

Each migration can have a companion rollback script:

```
migrations/20260215_0001_add-new-config.sh           # Migration
migrations/20260215_0001_add-new-config.rollback.sh   # Rollback companion
```

The rollback script reverses the migration's changes:

```bash
#!/usr/bin/env bash
# Rollback for: 20260215_0001_add-new-config.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

source "$REPO_ROOT/scripts/lib/logging.sh"

log_info "Rolling back: add-new-config"

# Reverse the migration changes
rm -f "$HOME/.config/new-app/config.toml"

log_success "Rollback complete"
```

## Running Migrations

### Migration Runner

The primary tool for managing migrations:

```bash
# Run all pending migrations (respects dependencies)
./scripts/install/run-migrations.sh

# Preview what would run (no changes applied)
./scripts/install/run-migrations.sh --dry-run

# List all migrations and their status
./scripts/install/run-migrations.sh --list

# Roll back a specific migration
./scripts/install/run-migrations.sh --rollback 20260111_0001_fontconfig-path-and-stow-safe-theme.sh

# Generate a full migration report
./scripts/install/run-migrations.sh --report

# Clear all migration markers (force re-run)
./scripts/install/run-migrations.sh --reset
```

### Automatic Integration

Migrations run automatically in two places:

1. **During installation** (`./install.sh`) — runs after host config setup
2. **During updates** (`./scripts/install/update.sh`) — runs after git pull

### Manual Execution

Migrations are standalone scripts and can be run individually:

```bash
# Run a specific migration
./migrations/20260111_0001_fontconfig-path-and-stow-safe-theme.sh

# Run all migrations in order (without state tracking)
for migration in migrations/*.sh; do
    [[ "$migration" == *.rollback.sh ]] && continue
    bash "$migration"
done
```

## State Tracking

Applied migrations are recorded using the shared install-state library.

**State directory:** `~/.local/state/dotfiles/install/`

**Step IDs:** `update:migration:<filename>`

**History log:** `~/.local/state/dotfiles/migration-history/migration.log`

The runner also imports legacy markers from `~/.local/state/dotfiles/migrations/` to avoid re-running already-applied migrations from older versions.

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

### 2. Use Descriptive Names and Comments

```bash
#!/usr/bin/env bash
# Migration: Add support for Wayland screensharing
# Date: 2026-02-15
# Author: DevOps Team
# Purpose: Install and configure xdg-desktop-portal-hyprland

set -euo pipefail
# ... migration code
```

### 3. Always Create Rollback Scripts for Destructive Operations

If a migration deletes, moves, or significantly changes files, create a rollback companion:

```bash
./scripts/utilities/add-migration.sh "reorganize-theme-files"
# Say "yes" when prompted to create a rollback companion
```

### 4. Declare Dependencies Explicitly

If your migration depends on another migration having run first:

```bash
# Depends: 20260111_0001_fontconfig-path-and-stow-safe-theme.sh
```

### 5. Test Before Committing

```bash
# Preview first
./scripts/install/run-migrations.sh --dry-run

# Run on a test system
bash migrations/20260215_0001_my-migration.sh

# Verify rollback works
./scripts/install/run-migrations.sh --rollback 20260215_0001_my-migration.sh
```

### 6. Handle Errors Gracefully

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! command -v some-tool &>/dev/null; then
    log_warning "some-tool not found, skipping this migration"
    exit 0  # Exit successfully — migration is a no-op on this system
fi
```

### 7. Use Centralized Logging

```bash
source "$REPO_ROOT/scripts/lib/logging.sh"

log_info "Starting migration..."
log_success "Migration complete"
log_warning "Optional step skipped"
log_error "Something went wrong"
```

## When to Use Migrations

Use migrations for:
- One-time configuration changes
- Package additions/removals
- Directory structure changes
- Service configuration updates
- Cleanup of deprecated files

Don't use migrations for:
- Regular package updates (use update scripts)
- Configuration changes managed by stow
- Temporary changes or experiments

### Migration vs. Setup Scripts

| Aspect | Migrations | Setup Scripts |
|--------|-----------|---------------|
| **Purpose** | One-time changes | Repeatable setup |
| **Frequency** | Once per system | Can run multiple times |
| **Tracking** | Install-state tracked | Not tracked |
| **Idempotency** | Should be idempotent | Must be idempotent |
| **Use Case** | Evolving config | Initial setup |
| **Rollback** | Supported via companions | N/A |
| **Dependencies** | Declared via headers | Implicit ordering |

## Workflow Example

1. **Make a dotfiles change** that requires a one-time update:
   ```bash
   vim packages/hyprland/.config/hypr/hyprland.conf
   ```

2. **Create a migration** for existing users:
   ```bash
   ./scripts/utilities/add-migration.sh "update-hyprland-feature"
   ```

3. **Write the migration** (editor opens automatically):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   # ... update existing systems
   ```

4. **Preview and test**:
   ```bash
   ./scripts/install/run-migrations.sh --dry-run
   bash migrations/20260215_0001_update-hyprland-feature.sh
   ```

5. **Commit both changes**:
   ```bash
   git add packages/hyprland/.config/hypr/hyprland.conf
   git add migrations/20260215_0001_update-hyprland-feature.sh
   git commit -m "feat(hyprland): add new feature with migration"
   ```

## Related Files

- `scripts/install/run-migrations.sh` - Migration runner (dry-run, rollback, reporting)
- `scripts/utilities/add-migration.sh` - Migration creator tool (with rollback + dependency support)
- `scripts/lib/install-state.sh` - State tracking library
- `scripts/lib/logging.sh` - Centralized logging for migrations
- `install.sh` - Main install script (runs migrations automatically)
- `scripts/install/update.sh` - Update script (runs migrations automatically)

## See Also

- Database migration systems (Flyway, Liquibase) for inspiration
- [Git hooks documentation](https://git-scm.com/docs/githooks)
- [Bash scripting best practices](https://google.github.io/styleguide/shellguide.html)
