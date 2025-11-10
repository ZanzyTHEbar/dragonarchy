# Dragon CLI

A unified command-line interface for managing themes, system utilities, and configurations across your dotfiles setup.

## Quick Start

```bash
# Launch interactive menu
dragon-cli

# Direct commands
dragon-cli theme        # Theme management
dragon-cli sddm         # SDDM theme management
dragon-cli cursors      # Cursor theme selection
dragon-cli fonts        # Font selection
dragon-cli keybindings  # Keybindings reference
dragon-cli power        # Power menu
dragon-cli background   # Change wallpaper
```

## Features

### Theme Management
- **Pick**: Choose from installed themes
- **Install**: Install new themes from git repositories
- **Update**: Update existing themes
- **Remove**: Remove installed themes
- **Change Background**: Set wallpaper
- **SDDM Themes**: Manage login screen themes

### SDDM Theme Management (NEW!)
Complete SDDM theme management integrated into the CLI:
- **List Themes**: View all available themes and their status
- **Select Theme**: Interactively choose and apply SDDM themes
- **Refresh/Update**: Install themes from dotfiles to system
- **Verify Setup**: Check SDDM configuration and theme installation

Available SDDM themes:
- catppuccin-mocha-sky-sddm (default)
- chili
- darkevil
- flateos
- sugar-dark
- sugar-light

### Cursor Themes
- Browse and select cursor themes
- Preview installed cursors
- Apply system-wide or per-user

### Utilities
- **NFS**: NFS mount management
- **Web Apps**: Web application launcher
- **Docker DBs**: Database container management
- **Secrets**: Age-encrypted secrets management
- **Add Migration**: Migration script generator
- **Netbird**: VPN client installation

### System Management
- **Update**: Update packages and system
- **Setup**: Run host-specific setup
- **Power Menu**: Shutdown, reboot, suspend options
- **Keybindings**: View keyboard shortcuts
- **Font Menu**: Select system fonts

## Usage

### Interactive Mode

Simply run without arguments to launch the interactive menu:

```bash
dragon-cli
```

Use arrow keys to navigate and Enter to select options.

### Direct Commands

Access specific features directly:

```bash
# Theme management
dragon-cli theme

# SDDM login screen themes
dragon-cli sddm

# Cursor themes
dragon-cli cursor
dragon-cli cursors

# Font selection
dragon-cli font
dragon-cli fonts

# Change wallpaper
dragon-cli background

# Keyboard shortcuts reference
dragon-cli keybindings

# Power options
dragon-cli power
```

## SDDM Theme Management

### Quick Access

```bash
dragon-cli sddm
```

### Features

1. **List Themes**
   - Shows all themes from dotfiles
   - Indicates which are installed on system
   - Highlights currently active theme
   - Visual status indicators (✓ installed, ○ not installed)

2. **Select Theme**
   - Interactive theme picker
   - Automatically configures SDDM
   - Changes take effect on next login

3. **Refresh/Update Themes**
   - Copies themes from dotfiles to `/usr/share/sddm/themes/`
   - Updates existing themes
   - Requires sudo access

4. **Verify Setup**
   - Comprehensive system check
   - Validates SDDM installation
   - Checks theme configuration
   - Verifies service status

### Example Workflow

```bash
# 1. Check current status
dragon-cli sddm → Verify Setup

# 2. Install themes from dotfiles
dragon-cli sddm → Refresh/Update Themes

# 3. List available themes
dragon-cli sddm → List Themes

# 4. Select a theme
dragon-cli sddm → Select Theme

# 5. Apply changes (reboot or restart SDDM)
sudo systemctl restart sddm  # Warning: ends current session
```

## Requirements

- `gum` - For interactive menus and prompts
- `bash` - Shell environment
- `stow` - Dotfiles management (for installation)
- `sddm` - Display manager (for SDDM theme features)

Install gum:
```bash
# Arch Linux
sudo pacman -S gum

# Other systems
# See: https://github.com/charmbracelet/gum
```

## Installation

Dragon CLI is installed automatically with the dotfiles:

```bash
./install.sh
```

The script is stowed from `packages/dragon-cli/.local/share/dragon/dragon-cli` to `~/.local/share/dragon/dragon-cli`.

Ensure `~/.local/share/dragon` is in your PATH, or create an alias:

```bash
# Add to ~/.zshrc or ~/.bashrc
alias dragon-cli="~/.local/share/dragon/dragon-cli"
```

## File Structure

```
packages/dragon-cli/
└── .local/
    └── share/
        └── dragon/
            └── dragon-cli@ → ../../../../../scripts/dragon-cli

scripts/
├── dragon-cli (main script)
├── theme-manager/
│   ├── sddm-menu
│   ├── sddm-set
│   ├── refresh-sddm
│   ├── theme-menu
│   ├── theme-set
│   ├── theme-install
│   ├── theme-update
│   ├── theme-remove
│   └── cursors/
│       └── cursor-menu
└── utilities/
    ├── verify-sddm-setup.sh
    ├── nfs.sh
    ├── web-apps.sh
    ├── docker-dbs.sh
    └── secrets.sh
```

## Menu Structure

```
Main Menu
├── Theme
│   ├── Pick
│   ├── Install
│   ├── Update
│   ├── Remove
│   ├── Change Background
│   └── SDDM Themes ←─ NEW!
│       ├── List Themes
│       ├── Select Theme
│       ├── Refresh/Update Themes
│       └── Verify Setup
├── Cursors
├── Utilities
│   ├── NFS
│   ├── Web Apps
│   ├── Docker DBs
│   ├── Secrets
│   ├── Add Migration
│   └── Netbird
├── Update
├── Setup
├── Power Menu
├── Keybindings
├── Font Menu
└── Exit
```

## Configuration

Dragon CLI automatically detects script locations using symlink resolution. No manual configuration is required.

The SDDM theme configuration is stored in:
```
/etc/sddm.conf.d/10-theme.conf
```

## Troubleshooting

### "Command not found"

Ensure the script is installed and in your PATH:

```bash
# Check if file exists
ls -la ~/.local/share/dragon/dragon-cli

# Add to PATH (add to ~/.zshrc)
export PATH="$HOME/.local/share/dragon:$PATH"

# Or create an alias
alias dragon-cli="~/.local/share/dragon/dragon-cli"
```

### "gum: command not found"

Install the gum dependency:

```bash
sudo pacman -S gum  # Arch Linux
# Or see: https://github.com/charmbracelet/gum
```

### "SDDM is not installed"

Install SDDM if you want to use SDDM theme features:

```bash
sudo pacman -S sddm  # Arch Linux
sudo systemctl enable sddm.service
```

### SDDM themes not appearing

Run the refresh command to install themes:

```bash
dragon-cli sddm → Refresh/Update Themes
```

Or manually:

```bash
~/dotfiles/scripts/theme-manager/refresh-sddm
```

### Scripts not found

Verify the symlink structure:

```bash
ls -la ~/.local/share/dragon/dragon-cli
# Should point to: ../../../../../scripts/dragon-cli

ls -la ~/dotfiles/scripts/dragon-cli
# Should be executable
```

Re-run the install script if needed:

```bash
cd ~/dotfiles
./install.sh --dotfiles-only
```

## Development

### Adding New Menu Options

Edit `scripts/dragon-cli` (changes automatically reflect in the package due to symlink):

1. Add direct command handler in the `case` statement at the top
2. Add menu option in appropriate menu function
3. Create handler function if needed
4. Test with `bash scripts/dragon-cli`

### Adding New Themes

SDDM themes should be placed in:
```
packages/sddm/usr/share/sddm/themes/your-theme-name/
```

Then refresh to install:
```bash
dragon-cli sddm → Refresh/Update Themes
```

## See Also

- [DRAGON_CLI_SDDM_THEMES.md](../../docs/DRAGON_CLI_SDDM_THEMES.md) - Detailed SDDM feature documentation
- [SDDM_THEME_FIX.md](../../docs/SDDM_THEME_FIX.md) - Technical details about SDDM setup
- Main dotfiles README: [../../README.md](../../README.md)

## License

Part of the personal dotfiles collection. Use freely for your own dotfiles setup.

