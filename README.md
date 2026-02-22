# Traditional Dotfiles Management with GNU Stow

This is a very opinionated Linux configuration, using hyprland, that is built on-top of CachyOS (ideally, there are no hard dependencies, use what you want) and inspired by _Omarchy_.

- **GNU Stow** for dotfiles/configuration management
- **Zsh scripts** for automation and setup
- **age/sops** for secrets management
- **Platform-specific package managers** for software installation (APT, AUR, etc.)

## Quick Start

It is recommended to clone the repository into your home directory.

```bash
# Clone and setup
git clone https://github.com/ZanzyTHEbar/dragonarchy ~/dotfiles
cd ~/dotfiles

# Run setup for your machine
./install.sh

# Or specific host setup
./install.sh --host dragon
```

> [!IMPORTANT]
> The current hosts are machines that I own, and are not representative of the general population.
> Be sure to create a new host configuration for your machine, use one of mine as a reference.

## Directory Structure

```bash
dragonarchy/
├── packages/           # Stow packages (dotfiles)
│   ├── zsh/            # Zsh configuration
│   ├── git/            # Git configuration
│   ├── kitty/          # Kitty terminal
│   ├── nvim/           # Neovim configuration
│   ├── ssh/            # SSH configuration
│   └── ...
├── scripts/
│   ├── lib/            # Shared libraries
│   │   ├── logging.sh          # Color-coded logging
│   │   ├── install-state.sh    # Idempotency markers
│   │   ├── system-mods.sh      # Safe /etc modifications with backups
│   │   ├── stow-helpers.sh     # Stow conflict resolution
│   │   ├── icons.sh            # Icon deployment
│   │   ├── fresh-mode.sh       # Fresh machine detection
│   │   ├── hosts.sh            # Host/trait detection
│   │   └── manifest-toml.sh    # TOML manifest parser
│   ├── install/        # Installation scripts
│   │   ├── install-deps.sh     # Package installer (supports --bundle)
│   │   ├── validate.sh         # System validation (supports --json)
│   │   └── first-run.sh        # First-run setup (firewall, timezone, themes)
│   ├── theme-manager/  # Theme management scripts
│   ├── utilities/      # Utility scripts
│   └── hardware/       # Hardware-specific scripts
├── hosts/              # Host-specific configurations (with .traits files)
├── secrets/            # Encrypted secrets management
├── .github/workflows/  # CI pipeline (shellcheck, validation)
├── install.sh          # Main setup script
└── README.md           # This file
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

# Application-specific toggles
./install.sh --cursor           # Force Cursor installation (default: Hyprland hosts only)
./install.sh --no-cursor        # Skip Cursor installation

# Combined examples
./install.sh --host dragon --cursor --no-theme --no-system-config
./install.sh --packages-only --utilities --no-secrets
./install.sh --dotfiles-only --no-shell --no-post-setup
```

> [!NOTE]
> Cursor is installed by default on Hyprland-configured hosts. Use `--cursor` to force installation on non-Hyprland hosts, or `--no-cursor` to skip it entirely.

## Package Bundles

Packages are defined in `scripts/install/deps.manifest.toml`. Bundles compose package groups into named profiles:

```bash
# Install only packages in a bundle
./scripts/install/install-deps.sh --bundle desktop   # Full Hyprland desktop
./scripts/install/install-deps.sh --bundle minimal   # CLI-only (server/container)
./scripts/install/install-deps.sh --bundle creative  # Desktop + multimedia tools
./scripts/install/install-deps.sh --bundle desktop_smb # Desktop + optional Nemo SMB/usershare support
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

## Docs

See [docs/](docs/) for more documentation.
