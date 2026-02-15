## Install System Elevation — Design & Implementation Record

### Overview

This document records the design decisions, implemented changes, and deferred items from the
installer elevation initiative. The goal was to improve the safety, modularity, and extensibility
of the DragonArchy dotfiles installer without introducing unnecessary complexity or redundant
abstraction layers.

### Guiding Principles

1. **Leverage what exists.** Build on the current GNU Stow / `install-state` / TOML manifest
   architecture rather than introducing parallel systems.
2. **Safety first.** Every privileged (`sudo`) operation goes through a centralized safety layer
   with automatic backups and idempotency.
3. **Incremental value.** Each phase delivers standalone improvements. No phase depends on
   future work to be useful.
4. **Headless by default.** Interactive/TUI features remain deferred until there's a concrete use
   case that justifies the dependency.

---

### Implemented Changes

#### Phase 0 — Install Script Decomposition

Broke the monolithic `install.sh` (~1571 lines) into focused library modules:

| New File | Extracted Functions | Purpose |
|---|---|---|
| `scripts/lib/stow-helpers.sh` | `fresh_backup_and_remove`, `purge_stow_conflicts_from_output`, `fresh_purge_stow_conflicts_for_package` | Stow conflict detection, backup, purge |
| `scripts/lib/icons.sh` | `refresh_icon_cache`, `deploy_dragon_icons`, `deploy_icon_aliases`, `deploy_icon_png_fallbacks` | Icon deployment and cache management |
| `scripts/lib/fresh-mode.sh` | `is_fresh_machine`, `maybe_enable_fresh_mode` | Fresh-machine detection and auto-enable |

`install.sh` now sources these modules and dropped to ~1041 lines. Hardcoded `/tmp/stow_output.txt`
paths were replaced with `mktemp`-generated secure temporaries.

#### Phase 1 — System Modifications Safety Layer

Created `scripts/lib/system-mods.sh` providing:

- `sysmod_install_file` / `sysmod_install_dir` — copy with SHA-256 idempotency
- `sysmod_tee_file` — write string content with content comparison
- `sysmod_append_if_missing` — append-only-if-absent
- `sysmod_ensure_service` / `sysmod_mask_service` — systemd service management
- `_sysmod_sudo` — transparent root escalation wrapper
- `_sysmod_backup` — timestamped backups under `/etc/.dragonarchy-backups`

All functions support `SYSMOD_DRY_RUN=1` for preview mode.

**Retrofitted all host setup scripts:**

| Host | Direct `sudo` Calls Replaced | Key Areas |
|---|---|---|
| `dragon` | 3 | DNS, LED service, liquidctl |
| `goldendragon` | 11 | PAM, udev rules, TLP, VPN, systemd |
| `firedragon` | 24 | xorg.conf, modprobe.d, sysctl.d, udev, polkit, ASUS |

#### Phase 2 — Declarative Package Bundles

Extended the existing `deps.manifest.toml` with a `[bundles]` section:

```toml
[bundles.desktop]
description = "Full desktop experience (Hyprland + GUI apps + themes)"
groups = ["core_cli", "dev", "fonts", "gui", "hyprland_base", "hyprland_core", "hyprland_aur"]

[bundles.minimal]
description = "CLI-only server/container setup"
groups = ["core_cli", "dev"]

[bundles.creative]
description = "Desktop + creative/multimedia tools"
groups = ["core_cli", "dev", "fonts", "gui", "hyprland_base", "hyprland_core", "hyprland_aur"]
```

Added to `scripts/lib/manifest-toml.sh`:
- `manifest_list_bundles()` — enumerate available bundles
- `manifest_bundle_groups()` — resolve bundle → group list

Added `--bundle NAME` flag to `scripts/install/install-deps.sh`:
- When set, only groups belonging to the named bundle are installed.
- Default behavior (install all groups) is unchanged.

**Design decision:** Bundles live inside the existing TOML manifest rather than in separate
`packages/bundles/*.yaml` files. This avoids a second configuration format and keeps `yq` as
the single parsing tool.

#### Phase 3 — Validation Improvements

Fixed `scripts/install/validate.sh`:

- **Counter fix:** Created `check_pass()`, `check_fail()`, `check_warn()` wrapper functions that
  both log output and increment `CHECKS_PASSED`/`CHECKS_FAILED`/`CHECKS_WARNING` counters.
  Previously, counters were declared but never incremented.

- **Host-aware validation:** Added `check_host_config()` which:
  - Auto-detects the current host via `detect_host()`
  - Validates Hyprland components if the host is a Hyprland desktop
  - Checks host-specific services (liquidctl, TLP, asusd, systemd-resolved)
  - Verifies `/etc` config files match their source in the repo (SHA-256 comparison)

- **JSON output:** Added `--json` flag that emits structured JSON:
  ```json
  {
    "status": "pass|warn|fail",
    "passed": 42,
    "failed": 0,
    "warnings": 3,
    "results": [{"status": "pass", "message": "..."}, ...]
  }
  ```
  Suitable for CI pipelines or future TUI consumption.

#### Phase 4 — First-Run Orchestrator

Created `scripts/install/first-run.sh` with four gated tasks:

1. **Firewall setup** — Configures `ufw` with sane defaults (deny incoming, allow outgoing,
   allow SSH). Skips gracefully if `ufw` is not installed.
2. **Timezone auto-detection** — Uses geo-IP to detect timezone; skips if already set to
   non-UTC value. Enables NTP synchronization.
3. **Theme verification** — Checks Plymouth, GTK, icon, cursor, and SDDM theme configuration
   and reports issues.
4. **Welcome message** — One-time display of next-steps guidance.

Each task uses `install-state` markers for idempotency.

Wired into `install.sh`:
- Auto-triggers when `FRESH_MODE` is true or the welcome marker hasn't been set.
- Opt-out via `--no-first-run` flag.
- Does not run in `--packages-only` or `--secrets-only` modes.

---

### Deferred Items

These items from the original plan were deliberately deferred:

#### Gum TUI Wrapper (`scripts/install/ui.sh`)

**Status:** Not implemented.
**Rationale:** The installer works well in headless mode. Adding a Gum dependency and maintaining
a presentation layer adds complexity with marginal benefit for the current single-user workflow.
The JSON output from `validate.sh` provides a machine-readable interface if a TUI is needed later.

**Prerequisite for revival:** A concrete user story that headless mode cannot satisfy.

#### Hardware Automation Module Framework (`scripts/hardware/modules/`)

**Status:** Not implemented as a generic framework.
**Rationale:** The host-specific setup scripts already encapsulate hardware detection and
configuration per-host. A generic module framework (with detection guards, auto-invocation)
would add an abstraction layer with no immediate consumer beyond the existing host scripts.
The `system-mods.sh` safety layer addresses the critical safety concern without the framework.

**Prerequisite for revival:** Support for a new hardware platform that doesn't map to a single
host (e.g., a module that applies across multiple hosts like "all NVIDIA hosts").

#### Sudoers Manipulation Helpers

**Status:** Not implemented.
**Rationale:** Manipulating sudoers files is high-risk and the current workflow (user enters
password when prompted) is adequate. The `_sysmod_sudo` wrapper handles privilege escalation
uniformly without touching sudoers configuration.

#### Package Bundle CLI Tool (`scripts/tools/package-bundles.sh`)

**Status:** Not implemented as a standalone tool.
**Rationale:** The `--bundle` flag on `install-deps.sh` provides the core functionality. A
separate diff/enable/disable CLI tool would be useful if bundles become more complex (e.g.,
user-defined bundles, bundle inheritance), but is premature for 3 static bundle definitions.

---

### Architecture Summary

```
install.sh
├── scripts/lib/
│   ├── logging.sh          — Log formatting
│   ├── install-state.sh    — Idempotency markers
│   ├── system-mods.sh      — Safe /etc modifications     [NEW]
│   ├── stow-helpers.sh     — Stow conflict resolution    [NEW]
│   ├── icons.sh            — Icon deployment              [NEW]
│   ├── fresh-mode.sh       — Fresh machine detection      [NEW]
│   ├── hosts.sh            — Host detection
│   └── manifest-toml.sh    — TOML manifest parser (+bundles)
├── scripts/install/
│   ├── install-deps.sh     — Package installer (+--bundle flag)
│   ├── validate.sh         — System validation (+--json, +host checks)
│   └── first-run.sh        — First-run tasks              [NEW]
├── hosts/
│   ├── dragon/setup.sh     — Retrofitted with sysmod_*
│   ├── goldendragon/setup.sh — Retrofitted with sysmod_*
│   └── firedragon/setup.sh — Retrofitted with sysmod_*
└── scripts/install/deps.manifest.toml — Package manifest (+[bundles])
```

### Key CLI Flags Added

| Flag | Script | Description |
|---|---|---|
| `--bundle NAME` | `install-deps.sh` | Install only packages in the named bundle |
| `--json` | `validate.sh` | Emit structured JSON results |
| `--host NAME` | `validate.sh` | Validate for a specific host |
| `--no-first-run` | `install.sh` | Skip first-run tasks |
| `--dry-run` | `first-run.sh` | Preview first-run changes |

#### Phase 6 — Post-Elevation Hardening

Implemented as a follow-up round after the core 5 phases:

- **Creative bundle hardened** with actual packages: GIMP, Inkscape, Blender, Kdenlive,
  Audacity, Ardour, OBS Studio, Krita, Darktable, Handbrake, mpv, DaVinci Resolve, REAPER.
- **CI pipeline** added (`.github/workflows/validate.yml`): shellcheck lint, bash syntax
  check, JSON validation smoke test, TOML manifest integrity check.
- **Old sudo helpers deprecated** in `install-state.sh`: `copy_if_changed`,
  `copy_dir_if_changed`, `install_service`, `restart_if_running` now emit deprecation
  warnings. All callers migrated to `sysmod_*` equivalents. Added `sysmod_restart_if_running`
  to `system-mods.sh`.
- **`--host NAME` flag** added to `validate.sh` for validating a different host's expectations
  without being on that machine.
- **Trait system** introduced via `hosts/<host>/.traits` files. Each host declares capabilities
  (e.g., `hyprland`, `tlp`, `aio-cooler`, `laptop`, `asus`, `fingerprint`). Validation is now
  trait-driven rather than hostname-hardcoded, making it extensible for future hosts without
  modifying `validate.sh`.

### Trait System

Each host directory contains a `.traits` file listing capabilities, one per line:

```
# hosts/dragon/.traits
amd-gpu
aio-cooler
hyprland
desktop
netbird
```

Available traits and what they validate:

| Trait | Validation Checks |
|---|---|
| `desktop` | systemd-resolved running |
| `hyprland` | Hyprland, hyprctl, waybar, hyprlock, hypridle, hyprpaper |
| `tlp` | TLP available, tlp service running, systemd-rfkill masked |
| `aio-cooler` | liquidctl available, cooler + LED services running |
| `asus` | asusd service running |
| `laptop` | brightnessctl available |
| `fingerprint` | fprintd available |

New hosts only need a `.traits` file to get automatic validation coverage.

### Future Considerations

- **Trait-driven first-run:** Extend `first-run.sh` to read traits and conditionally run
  tasks (e.g., only configure TLP on `tlp` hosts).
- **Trait-driven package bundles:** Map traits to package groups automatically, reducing
  manual bundle composition.
- **CI per-host matrix:** Use `.traits` files to generate a GitHub Actions matrix that
  validates each host configuration in parallel.
