# Dotfiles — Ansible + Chezmoi Control Plane

This is a very opinionated Linux configuration using Hyprland, built on CachyOS (no hard dependencies) and inspired by _Omarchy_.

- **Ansible** for system-level state (packages, services, hardware config)
- **chezmoi** for user-level dotfiles
- **Manifests** for declarative dotfile ownership
- **age/sops** for secrets management

The canonical managed-host path is now the Ansible + chezmoi control plane. The legacy GNU Stow + bash-script flow is deprecated and guarded, retained only for unmanaged profiles, recovery, and historical troubleshooting.

## Quick Start

```bash
# Clone and install
git clone https://github.com/ZanzyTHEbar/dragonarchy ~/dotfiles
cd ~/dotfiles

# Full install (system + user state)
./install --host <hostname>

# Or apply only system state (Ansible)
./install --host <hostname> --system-only

# Or apply only user state (chezmoi dotfiles)
./install --host <hostname> --user-only

# Preview changes without applying
./install --host <hostname> --dry-run
```

> [!IMPORTANT]
> The current hosts are machines that I own, and are not representative of the general population.
> Be sure to create a new host configuration for your machine, use one of mine as a reference.

## Architecture

This repository uses a **declarative control-plane architecture**:

| Domain | Tool | Owns |
|--------|------|------|
| **System state** | Ansible | Packages, services, kernel modules, `/etc` configs |
| **User state** | chezmoi | Dotfiles, shell config, application configs |
| **Secrets** | age/sops | Encrypted credentials and private keys |

The legacy GNU Stow + bash-script flow (`./install.sh`) is deprecated. Use `./install` for all new setups.

## Legacy Install (Deprecated)

The old `./install.sh` entrypoint and `scripts/install/setup.sh` orchestrator remain available only for explicit legacy or recovery work. Managed inventory hosts refuse this path unless `DOTFILES_LEGACY_INSTALL=1` is set. Use `./install` instead.

## Directory Structure

```bash
dragonarchy/
├── install             # Main entrypoint (Ansible + chezmoi)
├── packages/           # Canonical dotfile payloads (chezmoi-managed)
│   ├── zsh/            # Zsh configuration
│   ├── git/            # Git configuration
│   ├── kitty/          # Kitty terminal
│   ├── nvim/           # Neovim configuration
│   ├── ssh/            # SSH configuration
│   └── ...
├── hosts/              # Host-specific system configs and dotfile overlays
│   ├── dragon/         # AMD desktop workstation
│   ├── firedragon/     # ASUS laptop
│   ├── goldendragon/   # ThinkPad P16s
│   └── ...
├── infra/
│   ├── ansible/        # System-state control plane (packages, services, hardware)
│   │   ├── roles/      # Ansible roles (base, packages, sddm, hyprland, etc.)
│   │   ├── playbooks/  # Playbooks (foundation.yml, site.yml, edge-cases.yml)
│   │   └── inventory/  # Host inventory and variables
│   ├── chezmoi/        # User-state control plane (dotfiles)
│   │   ├── manifests/  # Canonical dotfile manifest declarations
│   │   └── bin/        # Sync tooling (chezmoi-sync)
│   └── packer/         # Proxmox validation template pipeline
├── scripts/
│   ├── lib/            # Shared libraries for legacy/support tooling
│   ├── install/        # Legacy installer support scripts
│   ├── theme-manager/  # Theme management scripts
│   ├── utilities/      # Utility scripts
│   └── hardware/       # Hardware-specific scripts
├── secrets/            # Encrypted secrets management
└── docs/               # Architecture docs and runbooks
```

## Script Entry Points

Executable logic lives under `scripts/` (e.g., `scripts/theme-manager`, `scripts/hardware`, `scripts/utilities`).  
Packages expose those commands via relative symlinks tracked in `scripts/tools/bin-links.manifest`.  

```bash
# Inspect the manifest
cat scripts/tools/bin-links.manifest

# Create or verify links (per package or entire repo)
scripts/tools/sync-bin-links --package hyprland
scripts/tools/sync-bin-links --check
```

When adding a new command:

1. Place the executable in the appropriate `scripts/<area>/` directory and make it executable.
2. Append an entry to `scripts/tools/bin-links.manifest` with `package=`, `target=` (canonical script), and `link=` (package `.local/bin` path).
3. Run `scripts/tools/sync-bin-links --package <name>` to generate or verify the package-local symlink.

This keeps every PATH-visible command sourced from a single canonical script while preserving per-package bin directories. Managed user-state application goes through `infra/chezmoi/bin/chezmoi-sync` and `./install --user-only`; direct Stow restows are legacy/manual recovery operations.

## Features

- **Declarative Configuration**: system state managed by Ansible and user state managed by chezmoi
- **Multi-Platform**: Linux (CachyOS/Arch) and Debian support
- **Host-Specific**: Different configs per machine with inventory-declared capabilities
- **Secrets Management**: Encrypted secrets with age/sops
- **Package Bundles**: Composable package profiles (desktop, minimal, creative)
- **Safe System Modifications**: Managed `/etc` changes go through Ansible roles with explicit ownership and validation
- **System Validation**: Host-aware validation with JSON output for CI
- **First-Run Orchestrator**: Firewall, timezone, theme verification for fresh installs
- **CI Pipeline**: Shellcheck, syntax checking, and validation via GitHub Actions
- **Networking**: Optional NetBird integration for secure networking
- **Modular**: Enable/disable components as needed

## Commands

### Basic Usage

```bash
./install --host dragon              # Complete managed-host setup
./install --host dragon --dry-run    # Preview Ansible + chezmoi changes
./install --host dragon --system-only  # Only apply Ansible system state
./install --host dragon --user-only    # Only apply chezmoi user state
./infra/validate-parity.sh --host dragon  # Check migration parity surface
```

### Legacy Installer Toggles

The old `./install.sh` flags below are retained only for unmanaged profiles or explicit recovery work. Managed hosts refuse this path unless `DOTFILES_LEGACY_INSTALL=1` is set.

```bash
# Component toggles
DOTFILES_LEGACY_INSTALL=1 ./install.sh --no-packages
DOTFILES_LEGACY_INSTALL=1 ./install.sh --no-dotfiles
DOTFILES_LEGACY_INSTALL=1 ./install.sh --no-secrets
DOTFILES_LEGACY_INSTALL=1 ./install.sh --utilities
DOTFILES_LEGACY_INSTALL=1 ./install.sh --no-utilities

# Step toggles
DOTFILES_LEGACY_INSTALL=1 ./install.sh --no-theme
DOTFILES_LEGACY_INSTALL=1 ./install.sh --no-shell
DOTFILES_LEGACY_INSTALL=1 ./install.sh --no-first-run
DOTFILES_LEGACY_INSTALL=1 ./install.sh --no-post-setup
DOTFILES_LEGACY_INSTALL=1 ./install.sh --no-system-config
DOTFILES_LEGACY_INSTALL=1 ./install.sh --bundle minimal
DOTFILES_LEGACY_INSTALL=1 ./install.sh --headless

# Application-specific toggles
DOTFILES_LEGACY_INSTALL=1 ./install.sh --cursor
DOTFILES_LEGACY_INSTALL=1 ./install.sh --no-cursor

# Combined examples
DOTFILES_LEGACY_INSTALL=1 ./install.sh --host headless --headless --no-secrets
```

> [!NOTE]
> Cursor is installed by default on Hyprland-configured hosts. Use `--cursor` to force installation on non-Hyprland hosts, or `--no-cursor` to skip it entirely.

### Control Plane Gating

Managed hosts use `./install`, which applies Ansible system state and chezmoi user state directly. Legacy control-plane gates are retained only for old scripts that may still be run manually:

```bash
DOTFILES_LEGACY_INSTALL=1 DOTFILES_SYSTEM_OWNER=ansible ./install.sh
DOTFILES_LEGACY_INSTALL=1 DOTFILES_USER_OWNER=chezmoi ./install.sh --dotfiles-only
DOTFILES_LEGACY_INSTALL=1 DOTFILES_SYSTEM_OWNER=ansible DOTFILES_USER_OWNER=chezmoi ./install.sh
```

Modes:

- `DOTFILES_SYSTEM_OWNER=legacy|ansible`
- `DOTFILES_USER_OWNER=stow|chezmoi`

`./install.sh` now refuses managed inventory hosts unless `DOTFILES_LEGACY_INSTALL=1` is set.

Use `DOTFILES_SYSTEM_OWNER=ansible` to gate legacy system writers such as system Stow, host `setup.sh`, legacy SDDM theme writes, and `scripts/install/system-config.sh`.

Use `DOTFILES_USER_OWNER=chezmoi` only after the relevant `$HOME` paths have been cut over, because it disables legacy user Stow for those runs.

## Package Bundles

Packages are defined in `scripts/install/deps.manifest.toml`. Ansible consumes this manifest through `infra/ansible/roles/packages` and `scripts/install/export-package-plan.sh`. Bundles compose package groups into named profiles:

```bash
# Install only packages in a bundle
./scripts/install/install-deps.sh --bundle desktop   # Full Hyprland desktop
./scripts/install/install-deps.sh --bundle minimal   # CLI-only (server/container)
./scripts/install/install-deps.sh --bundle creative  # Desktop + multimedia tools
./scripts/install/install-deps.sh --bundle desktop_smb # Desktop + optional Nemo SMB/usershare support

# Managed-host install uses the Ansible packages role through ./install
./install --host microdragon --system-only
```

Bundles are composable:
- `desktop_base` defines the shared Hyprland desktop foundation.
- `desktop` is now the base profile without SMB/usershare.
- `desktop_smb` extends `desktop_base` and adds only SMB/usershare pieces (`nemo_share`).
- `creative` extends `desktop_base` and adds creative payload groups.
- The installer resolves bundle inheritance in one pass and installs composed groups through
  the shared adapter composer (`install_platform_manager_batches`), so adding new
  bundle variants should be manifest-only.
- Package manager handling is adapter-driven in the installer: adding a new manager means
  registering an adapter and selector strategy, then wiring groups in the manifest,
  not adding new branch-specific install loops.
- The installer validates manifest managers at startup and refuses to proceed when no
  supported manager adapter is configured for the detected platform.

## System Validation

The primary migration parity check is read-only and validates inventory, role coverage, manifest sources, and legacy retirement markers:

```bash
./infra/validate-parity.sh --host dragon
./infra/validate-parity.sh --host firedragon
./infra/validate-parity.sh --host goldendragon
./infra/validate-parity.sh --host microdragon
```

The legacy validator remains available for historical troubleshooting, but it is not the canonical managed-host parity gate.

## Legacy Migration System

The legacy migration framework is retained for historical `install.sh` flows only. It is not part of the canonical Ansible + chezmoi managed-host path.

```bash
# Create a new migration
./scripts/utilities/add-migration.sh

# Migrations are stored in migrations/ (created on demand)
# Run them (tracked via install-state):
./scripts/install/run-migrations.sh

# Or run a full update (also runs migrations):
./scripts/install/update.sh

# Or you can use the dragon-cli to manage your dotfiles:
dragon-cli                       # Interactive main menu
dragon-cli theme                 # Theme management menu
dragon-cli cursors               # Cursor theme selector
dragon-cli utilities             # Utilities menu
dragon-cli utilities nfs         # Configure NFS mounts
dragon-cli utilities web-apps    # Create web application launchers
dragon-cli utilities docker-dbs  # Launch database containers
dragon-cli utilities secrets     # Secrets management menu
dragon-cli utilities add-migration  # Create new migration
dragon-cli utilities netbird     # Install NetBird VPN
dragon-cli update                # Update dotfiles
dragon-cli setup                 # Run setup script
dragon-cli power                 # Power menu
dragon-cli keybindings           # View keybindings
dragon-cli font                  # Font selector
```

## Centralized Logging

All scripts use a centralized logging library (`scripts/lib/logging.sh`) providing:

- Consistent color-coded output across all scripts
- Standard logging functions: `log_info`, `log_success`, `log_warning`, `log_error`, `log_step`
- Debug mode support: `DEBUG=1 ./script.sh`
- Single source of truth for all logging functionality

See [scripts/lib/README.md](scripts/lib/README.md) for usage details.

## Networking with NetBird

This setup includes NetBird for creating a secure peer-to-peer VPN. Managed hosts install and enable it through the Ansible `netbird` role when they are in the `netbird` inventory group.

To connect to your network, you will need to run the `netbird` command and follow the instructions.

## Supported Platforms

- **Linux**: CachyOS, Arch Linux, Debian (Ubuntu, etc.), other Arch & Debian-based distros
- **Debian**: via APT
- **Other Linux**: Partial support via common package managers (AUR, etc.)

## Debian Smoke Loop

Use the container smoke loop only for legacy terminal-only installer coverage:

```bash
bash ./scripts/ci/debian-headless-smoke.sh
bash ./scripts/ci/debian-headless-smoke.sh ubuntu:24.04
```

This loop exercises `./install.sh --host headless --headless --bundle minimal` in a Debian-family container with the legacy path.
Desktop/login-manager flows still require a VM or real machine because Docker does not model a full graphical session or systemd boot environment accurately enough for this repo.

For a real machine using the generic headless host profile, validate with:

```bash
./infra/validate-parity.sh --host microdragon
```

For the slower systemd-aware VM smoke lane:

```bash
bash ./scripts/ci/debian-vm-e2e.sh
```

That boots a Debian cloud image under QEMU, provisions the repo over SSH, runs the headless install twice for idempotency, then validates inside the guest.

## Proxmox Validation Templates

Use the Proxmox-backed template lane when you need a stronger disposable-machine substrate for Ansible + chezmoi validation:

```bash
cd infra/packer
./scripts/run-packer-build.sh \
  -only=debian-14-validation-template.proxmox-clone.debian_14_validation \
  -var-file=local.auto.pkrvars.hcl
```

This flow is intentionally separate from the QEMU CI smoke lane.

The wrapper is required because the Packer HCL is intentionally split across `builds/` and `sources/`, while `packer build .` only loads HCL files from the working directory.

Use it for:

- Debian and Arch disposable validation VMs
- desktop-class Arch graphical validation VMs
- branch shifts from `main` to `feat/ansible-chezmoi-foundation`
- dry-run validation before touching live hosts

Operator docs:

- `docs/architecture/proxmox-vm-template-strategy.md`
- `docs/runbooks/proxmox-validation-template-workflow.md`
- `docs/archive/migration-2026-05/first-safe-cutover-rollout-gate.md` (historical gate; adapt to the current `chezmoi-sync` model before executing)

## Docs

See [docs/](docs/) for more documentation.
