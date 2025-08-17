# Dragonarchy Dotfiles Management

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

This is a dotfiles management repository using GNU Stow for Arch Linux-based systems (particularly CachyOS) with Hyprland window manager. The system manages configuration files for development tools, shell environments, and desktop applications.

## Working Effectively

Bootstrap and setup the repository:
- **Install core dependencies (Ubuntu/Debian):**
  - `sudo apt-get update`
  - `sudo apt-get install -y zsh stow git curl grep sed gawk jq`
- **Install recommended development tools:**
  - `sudo apt-get install -y neovim ripgrep fd-find fzf tmux htop tree rsync`
- *Note:*
  - Some packages may have different names on other distributions (e.g., `fd-find` on Ubuntu/Debian, `fd` on Arch).
  - If a package is not available, you may skip it or install it manually.
  - The above lists are for convenience; you may install only the packages you need.
- `./setup.sh --help` -- View all available options
- `./setup.sh --dotfiles-only --no-secrets` -- Quick dotfiles setup (takes 1-2 seconds). NEVER CANCEL. Creates symlinks for all dotfiles.
- `./setup.sh --packages-only` -- Install packages only (may take 10-30 minutes on Arch, WILL FAIL on non-Arch systems). NEVER CANCEL. Set timeout to 45+ minutes.
- `./setup.sh` -- Complete setup including packages, dotfiles, and secrets (may take 30-60 minutes on Arch). NEVER CANCEL. Set timeout to 90+ minutes.

Validate and test the setup:
- `chmod +x ./scripts/install/validate.sh && ./scripts/install/validate.sh` -- System validation (takes 10-30 seconds). NEVER CANCEL.
- `./scripts/install/update.sh` -- Update packages and dotfiles (takes 5-15 minutes on Arch only). NEVER CANCEL. Set timeout to 30+ minutes.

Manual verification after dotfiles setup:
- `ls -la ~/.zshrc ~/.gitconfig ~/.config/nvim/` -- Verify symlinks were created
- `stow --version` -- Confirm stow is working (should show version 2.3.1+)

## Host-Specific Setup

Support for multiple machines with different configurations:
- `./setup.sh --host dragon` -- Setup for desktop machine
- `./setup.sh --host spacedragon` -- Setup for laptop with power management
- `./setup.sh --host microdragon` -- Setup for mini PC
- Available hosts: dragon, spacedragon, dragonsmoon, microdragon, goldendragon

## Package Management

The system uses platform-appropriate package managers:
- **Arch Linux**: pacman + paru (AUR helper)
- **macOS**: homebrew
- **Debian/Ubuntu**: apt + manual installations for modern tools

Package categories:
- Core CLI tools: zsh, git, neovim, stow, fzf, ripgrep, fd, bat, etc.
- Development: go, ansible, terraform, docker, github-cli
- Hyprland desktop: waybar, swaync, hyprshot, etc.
- Fonts: JetBrains Mono Nerd Font, Font Awesome, etc.

## Secrets Management

Uses age/sops for encrypted secrets:
- `./scripts/utilities/secrets.sh setup` -- Initial secrets setup
- `./scripts/utilities/secrets.sh create` -- Create encrypted secrets from user input
- `./scripts/utilities/secrets.sh edit` -- Edit encrypted secrets
- `./scripts/utilities/secrets.sh verify` -- Verify secrets can be decrypted
- Age keys stored in `~/.config/sops/age/keys.txt`
- SOPS configuration in `.sops.yaml`

## Theme Management

Integrated theme management system:
- `scripts/theme-manager/theme-install` -- Install new themes
- `scripts/theme-manager/theme-set` -- Set active theme
- `scripts/theme-manager/theme-next` -- Switch to next theme
- `scripts/theme-manager/theme-menu` -- Interactive theme selector
- `scripts/theme-manager/generate-kitty-themes` -- Generate Kitty terminal themes

## Validation

Always manually validate changes by running complete scenarios:
- **Essential validation**: `./setup.sh --dotfiles-only --no-secrets` (takes <1 second)
- **Verify symlinks**: `ls -la ~/.zshrc ~/.gitconfig ~/.config/nvim/` should show symlinks
- **Test tools**: `stow --version && git --version && nvim --version`
- **Configuration check**: All dotfiles should be symlinked, not copied

NEVER test package installation on non-Arch systems - it will fail and waste time.

## Development Workflow

Making changes to the dotfiles:
- **Always test with `./setup.sh --dotfiles-only --no-secrets` first**
- **Verify changes work**: Check that symlinks are created correctly
- **Run validation**: `./scripts/install/validate.sh` (optional, may show warnings)
- For package changes, test on a disposable Arch system or container
- Host-specific changes go in `hosts/<hostname>/` directories
- Theme changes go in `scripts/theme-manager/` or `packages/themes/`

## Common Tasks

### Repository Structure
```
.
├── README.md                 # Main documentation
├── setup.sh                  # Main setup script
├── packages/                 # Stow packages (dotfiles)
│   ├── zsh/                  # Zsh configuration
│   ├── git/                  # Git configuration  
│   ├── nvim/                 # Neovim configuration
│   ├── hyprland/             # Hyprland window manager
│   └── ...                   # Other application configs
├── scripts/                  # Installation and utility scripts
│   ├── install/              # Installation scripts
│   ├── utilities/            # Utility scripts
│   └── theme-manager/        # Theme management
├── hosts/                    # Host-specific configurations
├── secrets/                  # Encrypted secrets
└── .sops.yaml               # SOPS configuration
```

### Key Scripts
```bash
# Main setup script options
./setup.sh                    # Complete setup
./setup.sh --host dragon      # Setup for specific host  
./setup.sh --packages-only    # Only install packages
./setup.sh --dotfiles-only    # Only setup dotfiles
./setup.sh --no-secrets       # Skip secrets setup

# Validation and updates  
./scripts/install/validate.sh # Validate system health
./scripts/install/update.sh   # Update packages and configs

# Secrets management
./scripts/utilities/secrets.sh setup  # Setup secrets
./scripts/utilities/secrets.sh create # Create encrypted secrets
./scripts/utilities/secrets.sh edit   # Edit secrets
./scripts/utilities/secrets.sh verify # Verify secrets

# Theme management
scripts/theme-manager/theme-install    # Install themes
scripts/theme-manager/theme-set       # Set active theme
scripts/theme-manager/theme-menu      # Interactive theme selector
```

### Package Lists
Essential CLI tools validated to work:
- zsh, git, stow, curl, grep, sed, awk, jq
- neovim, bat, lsd, fzf, ripgrep, fd, zoxide
- direnv, age, sops, tmux, htop, tree, rsync

Arch-specific packages:
- hyprland, waybar, swaync, hyprshot (desktop environment)
- lazygit, github-cli, terraform (development)
- ttf-jetbrains-mono-nerd, noto-fonts (fonts)

### Troubleshooting
- If stow fails: Remove conflicting files in home directory first with `rm ~/.zshrc ~/.gitconfig` etc.
- If packages fail on non-Arch: Many packages may not be available (e.g., bat-cat, diff-so-fancy, terraform on Ubuntu)
- If secrets fail: Ensure age and sops are installed and keys are generated
- If validation fails: Check missing dependencies and install manually
- If zsh config has warnings: Ignore "insecure directories" warnings - this is normal on shared systems
- Package installation script WILL FAIL on Ubuntu/Debian due to missing packages - this is expected

### Platform Limitations
- **Full functionality requires Arch Linux or compatible distribution**
- **Package installation only works on Arch Linux** - scripts/install/install_deps.sh will fail on other platforms
- macOS has partial support via homebrew
- Ubuntu/Debian: Dotfiles work fine, but many packages are not available (bat-cat vs bat, fd-find vs fd, etc.)
- Windows is not supported

### Non-Arch System Usage
On Ubuntu/Debian systems:
- Use `./setup.sh --dotfiles-only --no-secrets` for configuration files only
- Install available packages manually: `sudo apt-get install neovim ripgrep fd-find fzf bat tmux`
- Note package/command differences on Ubuntu/Debian: package `bat` installs the command `batcat`; package `fd-find` installs the command `fdfind`
- Skip package installation completely with `./setup.sh --no-packages`

## Critical Warnings
- **NEVER CANCEL package installations** - they may take 30+ minutes on Arch Linux
- **NEVER CANCEL system updates** - they may take 15+ minutes on Arch Linux
- **Always use appropriate timeouts**: 45+ minutes for package installs, 30+ minutes for updates
- **Test dotfiles changes with `--dotfiles-only --no-secrets` before full setup** (takes <1 second)
- **Do NOT attempt package installation on non-Arch systems** - it will fail immediately
- **Backup existing configurations before running setup on a new system**
- **The validation script may show warnings on Ubuntu/Debian** - this is normal and expected
- **Zsh configuration warnings about "insecure directories" are normal** on shared systems