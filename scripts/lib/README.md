# Scripts Library (lib/)

Centralized utilities and shared functions for all dotfiles scripts.

## Available Libraries

### `logging.sh`

Provides standardized logging functions with color-coded output.

#### Available Functions

- `log_info "message"` - Blue info messages
- `log_success "message"` - Green success messages
- `log_warning "message"` - Yellow warning messages
- `log_error "message"` - Red error messages
- `log_step "message"` - Cyan step/progress messages
- `log_debug "message"` - Purple debug messages (only shown if `DEBUG=1`)
- `log_fatal "message"` - Red fatal error that exits the script

#### Usage in Your Scripts

**Step 1:** Add the source statement at the top of your script (after set flags):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging utilities
source "${SCRIPT_DIR}/path/to/logging.sh"
```

**Step 2:** Adjust the path based on your script's location:

| Script Location | Source Path |
|----------------|-------------|
| `/dotfiles/setup.sh` | `${SCRIPT_DIR}/scripts/lib/logging.sh` |
| `/dotfiles/scripts/*.sh` | `${SCRIPT_DIR}/lib/logging.sh` |
| `/dotfiles/scripts/install/*.sh` | `${SCRIPT_DIR}/../lib/logging.sh` |
| `/dotfiles/scripts/install/setup/*.sh` | `${SCRIPT_DIR}/../../lib/logging.sh` |
| `/dotfiles/scripts/utilities/*.sh` | `${SCRIPT_DIR}/../lib/logging.sh` |
| `/dotfiles/scripts/theme-manager/*.sh` | `${SCRIPT_DIR}/../lib/logging.sh` |

**Step 3:** Remove your local color and logging function definitions:

Delete these sections from your scripts:

```bash
# DELETE THIS:
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# DELETE THIS:
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
# ... etc
```

#### Example: Complete Migration

**Before:**

```bash
#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

main() {
    log_info "Starting..."
    log_error "Something failed"
}

main "$@"
```

**After:**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/logging.sh"  # Adjust path as needed

main() {
    log_info "Starting..."
    log_error "Something failed"
}

main "$@"
```

#### Benefits

✅ **Single source of truth** - Update logging format once, applies everywhere  
✅ **Consistency** - All scripts use identical logging  
✅ **Maintainability** - No duplicate code across 27+ scripts  
✅ **Extensibility** - Easy to add new logging levels or features  
✅ **Testability** - Can mock or redirect logging in one place  

#### Debug Mode

Enable debug logging by setting the `DEBUG` environment variable:

```bash
DEBUG=1 ./your-script.sh
```

### `install-state.sh`

Provides idempotency for installation steps by tracking completed tasks via marker files.

#### Key Functions

- `is_step_completed "step-name"` — Check if a step has been completed
- `mark_step_completed "step-name"` — Mark a step as done
- `reset_step "step-name"` — Force re-run of a step
- `reset_all_steps` — Clear all state markers
- `files_differ "src" "dest"` — Compare files by SHA-256
- `is_package_installed "pkg"` — Check if a system package is installed

#### Usage

```bash
source "${SCRIPT_DIR}/../lib/install-state.sh"

if ! is_step_completed "my-setup-task"; then
    # Do the work...
    mark_step_completed "my-setup-task"
fi
```

State is stored in `~/.local/state/dotfiles/install/`.

### `system-mods.sh`

Safe, idempotent system file modification helpers with automatic backups.

#### Key Functions

- `sysmod_install_file SRC DEST [MODE] [OWNER]` — Copy file with SHA-256 idempotency
- `sysmod_install_dir SRC DEST [OWNER]` — Recursive directory copy with diff check
- `sysmod_tee_file DEST CONTENT [MODE]` — Write string content to a file
- `sysmod_append_if_missing FILE LINE` — Append line only if absent
- `sysmod_ensure_service NAME [UNIT_FILE]` — Enable and start a systemd service
- `sysmod_mask_service NAME` — Mask a systemd service
- `sysmod_restart_if_running NAME` — Restart only if currently active
- `_sysmod_sudo` — Run a command with sudo (transparent if already root)

All functions create timestamped backups under `/etc/.dragonarchy-backups/` and support `SYSMOD_DRY_RUN=1` for preview mode.

#### Usage

```bash
source "${SCRIPT_DIR}/../lib/system-mods.sh"

sysmod_install_file "./my-config" /etc/myapp/config.conf 644 root:root
sysmod_tee_file /etc/sysctl.d/99-custom.conf "vm.swappiness = 10"
sysmod_ensure_service "my-daemon.service" "./my-daemon.service"
```

### `stow-helpers.sh`

GNU Stow conflict detection, backup, and purge helpers for fresh-mode installation.

#### Key Functions

- `fresh_backup_and_remove PATH BACKUP_ROOT PACKAGE` — Safely backup and remove a conflicting target
- `purge_stow_conflicts_from_output PACKAGE BACKUP_ROOT OUTPUT_FILE` — Parse stow error output and purge conflicts
- `fresh_purge_stow_conflicts_for_package PACKAGE BACKUP_ROOT` — Pre-emptively purge all conflicts for a package

### `icons.sh`

Icon deployment helpers for Dragon icons, aliases, and PNG fallbacks.

#### Key Functions

- `refresh_icon_cache` — Refresh GTK icon cache
- `deploy_dragon_icons` — Generate and install Dragon Control icons
- `deploy_icon_aliases` — Create icon symlink aliases
- `deploy_icon_png_fallbacks` — Generate PNG fallbacks from SVGs via rsvg-convert

### `fresh-mode.sh`

Fresh machine detection for the dotfiles installer.

#### Key Functions

- `is_fresh_machine` — Returns 0 if no stow-managed symlinks exist
- `maybe_enable_fresh_mode` — Auto-enables FRESH_MODE when no existing dotfile links found

### `hosts.sh`

Host discovery, feature detection, and trait system.

#### Key Functions

- `detect_host HOSTS_DIR` — Detect current hostname
- `get_available_hosts HOSTS_DIR` — List all host directories
- `is_hyprland_host HOSTS_DIR HOSTNAME` — Check if host uses Hyprland
- `host_traits HOSTS_DIR HOSTNAME` — List all traits for a host
- `host_has_trait HOSTS_DIR HOSTNAME TRAIT` — Check if a host has a specific trait
- `host_traits_summary HOSTS_DIR HOSTNAME` — Comma-separated trait summary

#### Trait System

Each host can declare capabilities via `hosts/<hostname>/.traits`:

```
# One trait per line, comments supported
hyprland
laptop
tlp
amd-gpu
```

### `manifest-toml.sh`

TOML manifest parser for `deps.manifest.toml` using `yq`.

#### Key Functions

- `manifest_groups_for_platform MANIFEST PLATFORM MANAGER` — List package groups
- `manifest_group_packages MANIFEST PLATFORM MANAGER GROUP` — Get packages in a group
- `manifest_list_bundles MANIFEST` — List all bundle names
- `manifest_bundle_groups MANIFEST BUNDLE` — Resolve bundle to group list

### `notifications.sh`

Provides a single helper for sending desktop notifications consistently.

#### Available Functions

- `notify_send [--app name] [--icon name] [--urgency level] [--expire ms] [--timeout duration] [--action key=Label] [--wait] -- "Title" "Body"`

#### Usage

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/notifications.sh"  # Adjust path as needed

notify_send --app "My Script" "Done" "All tasks completed"
```
