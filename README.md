# Traditional Dotfiles Management with GNU Stow

This is a very opinionated Arch Linux configuration, using hyprland, that is built on-top of CachyOS and inspired from Omarchy.

- **GNU Stow** for dotfiles/configuration management
- **Zsh scripts** for automation and setup
- **age/sops** for secrets management
- **Platform-specific package managers** for software installation

## Quick Start

```bash
# Clone and setup
git clone <repository> ~/dotfiles
cd ~/dotfiles

# Run setup for your machine
./setup.sh

# Or specific host setup
./setup.sh --host dragon
```

## Directory Structure

```
stow-config/
├── packages/      # Stow packages (dotfiles)
│   ├── zsh/           # Zsh configuration
│   ├── git/             # Git configuration
│   ├── kitty/          # Kitty terminal
│   ├── nvim/         # Neovim configuration
│   ├── ssh/           # SSH configuration
│   └── ...
├── scripts/          # Installation and setup scripts
├── hosts/            # Host-specific configurations
├── secrets/         # Encrypted secrets management
└── setup.sh        # Main setup script
```

## Features

- ✅ **Declarative Configuration**: All dotfiles managed via Stow
- ✅ **Multi-Platform**: Linux (CachyOS/Arch) and macOS support
- ✅ **Host-Specific**: Different configs per machine
- ✅ **Secrets Management**: Encrypted secrets with age/sops
- ✅ **Package Management**: Platform-appropriate package installation
- ✅ **Networking**: NetBird integration for secure networking
- ✅ **Modular**: Enable/disable components as needed

## Commands

```bash
./setup.sh                    # Complete setup
./setup.sh --host dragon      # Setup for specific host
./setup.sh --packages-only    # Only install packages
./setup.sh --dotfiles-only    # Only setup dotfiles
./scripts/secrets.sh --help   # Secrets management
./scripts/update.sh           # Update packages and configs
./scripts/validate.sh         # Validate setup
```

## Networking with NetBird

This setup includes NetBird for creating a secure peer-to-peer VPN. The `system_config.sh` script will automatically install and enable the NetBird service.

To connect to your network, you will need to run the `netbird` command and follow the instructions.

## Supported Platforms

- **Linux**: CachyOS, Arch Linux, other Arch-based distros
- **macOS**: via Homebrew
- **Other Linux**: Partial support via common package managers
