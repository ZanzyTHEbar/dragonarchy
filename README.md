# Dotfiles — Ansible + Chezmoi Control Plane

This is a very opinionated Linux configuration using Hyprland, built on CachyOS (no hard dependencies) and inspired by _Omarchy_.

- **Ansible** for system-level state (packages, services, hardware config)
- **chezmoi** for user-level dotfiles
- **Manifests** for declarative dotfile ownership
- **age/sops** for secrets management

The legacy GNU Stow + bash-script flow has been retired. The new architecture is fully declarative and idempotent.

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

The old `./install.sh` entrypoint and `scripts/install/setup.sh` orchestrator are being migrated to Ansible roles. They remain functional but are no longer the canonical path. Use `./install` instead.

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
│   ├── lib/            # Shared libraries (legacy, being migrated)
│   ├── install/        # Legacy installation scripts (being migrated to Ansible)
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
3. Run `scripts/tools/sync-bin-links --package <name>` to generate the symlink, then restow the package.

This keeps every PATH-visible command sourced from a single canonical script while preserving per-package bin directories for GNU Stow.

## Features

- **Declarative Configuration**: All dotfiles managed via Stow
- **Multi-Platform**: Linux (CachyOS/Arch) and Debian support
- **Host-Specific**: Different configs per machine with trait-based capabilities
- **Secrets Management**: Encrypted secrets with age/sops
- **Package Bundles**: Composable package profiles (desktop, minimal, creative)
- **Safe System Modifications**: All `/etc` changes go through `system-mods.sh` with automatic backups and idempotency
- **System Validation**: Host-aware validation with JSON output for CI
- **First-Run Orchestrator**: Firewall, timezone, theme verification for fresh installs
- **CI Pipeline**: Shellcheck, syntax checking, and validation via GitHub Actions
- **Networking**: Optional NetBird integration for secure networking
- **Modular**: Enable/disable components as needed

## Commands

### Basic Usage

```bash
./install.sh                    # Complete setup
./install.sh --host dragon      # Setup for specific host
./install.sh --packages-only    # Only install packages
./install.sh --dotfiles-only    # Only setup dotfiles
./scripts/utilities/secrets.sh --help     # Secrets management
./scripts/install/update.sh             # Update packages and configs
./scripts/install/validate.sh           # Validate setup
./scripts/install/validate.sh --json    # JSON output (for CI/TUI)
./scripts/install/validate.sh --host firedragon  # Validate specific host
./scripts/install/install-deps.sh --bundle minimal  # Install a package bundle
./scripts/install/first-run.sh --dry-run  # Preview first-run tasks
```

### Feature Toggles

Fine-grained control over what gets installed and configured:

```bash
# Component toggles
./install.sh --no-packages      # Skip package installation
./install.sh --no-dotfiles      # Skip dotfiles setup
./install.sh --no-secrets       # Skip secrets management
./install.sh --utilities        # Symlink selected utilities to ~/.local/bin
./install.sh --no-utilities     # Skip utilities symlinking

# Step toggles
./install.sh --no-theme         # Skip Plymouth theme setup
./install.sh --no-shell         # Skip shell configuration (zsh)
./install.sh --no-first-run     # Skip first-run tasks (firewall, timezone, themes)
./install.sh --no-post-setup    # Skip post-setup tasks
./install.sh --no-system-config # Skip system-level configuration (PAM, services)
./install.sh --bundle minimal   # Install only a named package bundle
./install.sh --headless         # Terminal-only install mode (defaults bundle to minimal)

# Application-specific toggles
./install.sh --cursor           # Force Cursor installation (default: Hyprland hosts only)
./install.sh --no-cursor        # Skip Cursor installation

# Combined examples
./install.sh --host dragon --cursor --no-theme --no-system-config
./install.sh --host headless --headless --no-secrets
./install.sh --packages-only --utilities --no-secrets
./install.sh --dotfiles-only --no-shell --no-post-setup
```

> [!NOTE]
> Cursor is installed by default on Hyprland-configured hosts. Use `--cursor` to force installation on non-Hyprland hosts, or `--no-cursor` to skip it entirely.

### Control Plane Gating

When you are intentionally pivoting away from legacy writers, use environment flags to keep the old installer from rewriting state now owned by Ansible or chezmoi:

```bash
DOTFILES_SYSTEM_OWNER=ansible ./install.sh
DOTFILES_USER_OWNER=chezmoi ./install.sh --dotfiles-only
DOTFILES_SYSTEM_OWNER=ansible DOTFILES_USER_OWNER=chezmoi ./install.sh
```

Modes:

- `DOTFILES_SYSTEM_OWNER=legacy|ansible`
- `DOTFILES_USER_OWNER=stow|chezmoi`

Defaults preserve the legacy installer behavior.

Use `DOTFILES_SYSTEM_OWNER=ansible` to gate legacy system writers such as system Stow, host `setup.sh`, legacy SDDM theme writes, and `scripts/install/system-config.sh`.

Use `DOTFILES_USER_OWNER=chezmoi` only after the relevant `$HOME` paths have been cut over, because it disables legacy user Stow for those runs.

## Package Bundles

Packages are defined in `scripts/install/deps.manifest.toml`. Bundles compose package groups into named profiles:

```bash
# Install only packages in a bundle
./scripts/install/install-deps.sh --bundle desktop   # Full Hyprland desktop
./scripts/install/install-deps.sh --bundle minimal   # CLI-only (server/container)
./scripts/install/install-deps.sh --bundle creative  # Desktop + multimedia tools
./scripts/install/install-deps.sh --bundle desktop_smb # Desktop + optional Nemo SMB/usershare support

# Top-level installer using the generic headless host
./install.sh --host headless --headless
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

The validation script checks system health, dotfile integrity, and host-specific requirements:

```bash
./scripts/install/validate.sh              # Interactive output
./scripts/install/validate.sh --json       # Structured JSON (for CI/TUI)
./scripts/install/validate.sh --host dragon  # Validate a specific host
```

Validation is trait-driven: each host declares capabilities via `hosts/<hostname>/.traits` (e.g., `hyprland`, `tlp`, `aio-cooler`). The validator checks services, tools, and config drift based on those traits.

## Migration System

This repository includes a migration system for managing one-time setup tasks and configuration updates. See [MIGRATION-SYSTEM.md](docs/MIGRATION-SYSTEM.md) for detailed documentation.

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

This setup includes NetBird for creating a secure peer-to-peer VPN. The `system-config.sh` script will automatically install and enable the NetBird service.

To connect to your network, you will need to run the `netbird` command and follow the instructions.

## Supported Platforms

- **Linux**: CachyOS, Arch Linux, Debian (Ubuntu, etc.), other Arch & Debian-based distros
- **Debian**: via APT
- **Other Linux**: Partial support via common package managers (AUR, etc.)

## Debian Smoke Loop

Use the container smoke loop to verify the terminal-only Debian install path locally:

```bash
bash ./scripts/ci/debian-headless-smoke.sh
bash ./scripts/ci/debian-headless-smoke.sh ubuntu:24.04
```

This loop exercises `./install.sh --host headless --headless --bundle minimal` in a Debian-family container.
Desktop/login-manager flows still require a VM or real machine because Docker does not model a full graphical session or systemd boot environment accurately enough for this repo.

For a real machine using the generic headless host profile, validate with:

```bash
./scripts/install/validate.sh --host headless
```

For the slower systemd-aware VM smoke lane:

```bash
bash ./scripts/ci/debian-vm-e2e.sh
```

That boots a Debian cloud image under QEMU, provisions the repo over SSH, runs the headless install twice for idempotency, then validates inside the guest.

## Proxmox Validation Templates

Use the Proxmox-backed template lane when you need a stronger disposable-machine substrate for branch-shift and chezmoi cutover validation:

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
- first-host cutover rehearsal before touching live hosts

Operator docs:

- `docs/architecture/proxmox-vm-template-strategy.md`
- `docs/runbooks/proxmox-validation-template-workflow.md`
- `docs/runbooks/first-safe-cutover-rollout-gate.md`

## Docs

See [docs/](docs/) for more documentation.
