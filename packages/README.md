# Dotfiles Packages

This directory contains modular configuration packages that are installed using [GNU Stow](https://www.gnu.org/software/stow/).

## Package Auto-Detection

Packages are **automatically detected** using marker files. No need to edit `install.sh` when adding or removing packages!

### Quick Start

**Enable a package:**
```bash
touch packages/PACKAGE_NAME/.package
```

**Disable a package:**
```bash
rm packages/PACKAGE_NAME/.package
```

**Verify which packages are enabled:**
```bash
bash scripts/utilities/verify-package-detection.sh
```

## Creating a New Package

```bash
# 1. Create package directory
mkdir -p packages/myapp/.config/myapp

# 2. Add your configuration
echo "config content" > packages/myapp/.config/myapp/config.conf

# 3. Enable the package
touch packages/myapp/.package

# 4. Install
./install.sh --dotfiles-only
```

The structure inside `packages/myapp/` should mirror your home directory:
- `packages/myapp/.config/myapp/config.conf` → `~/.config/myapp/config.conf`
- `packages/myapp/.local/bin/script` → `~/.local/bin/script`

## Available Packages

| Package | Description |
|---------|-------------|
| `alacritty` | Alacritty terminal emulator configuration |
| `applications` | Desktop application entries |
| `dragon-cli` | Dragon CLI tool configuration |
| `fastfetch` | Fastfetch system information tool |
| `fcitx5` | Fcitx5 input method framework |
| `fonts` | Font configurations |
| `gh-extensions` | GitHub CLI extensions |
| `git` | Git configuration and aliases |
| `gpg` | GPG configuration |
| `gtk-3.0` | GTK 3 theming |
| `gtk-4.0` | GTK 4 theming |
| `hardware` | Hardware-specific configurations and scripts |
| `hyprland` | Hyprland wayland compositor configuration |
| `icons-in-terminal` | Terminal icon support |
| `kitty` | Kitty terminal emulator configuration |
| `lazygit` | Lazygit TUI configuration |
| `nvim` | Neovim configuration |
| `qt5ct` | Qt5 configuration tool settings |
| `sddm` | SDDM display manager themes |
| `ssh` | SSH configuration |
| `themes` | System themes and styling |
| `tmux` | Tmux terminal multiplexer configuration |
| `typora` | Typora markdown editor themes |
| `wlogout` | Wlogout logout menu configuration |
| `xournalpp` | Xournal++ note-taking app settings |
| `zed` | Zed editor configuration |
| `zsh` | Zsh shell configuration and plugins |

## How It Works

1. **Detection**: `install.sh` scans for `.package` marker files
2. **Installation**: GNU Stow creates symlinks from packages to `$HOME`
3. **Result**: Your configs stay in the git repo, symlinked to the right locations

### Example

```bash
packages/git/.gitconfig  →  ~/.gitconfig
packages/nvim/.config/nvim/  →  ~/.config/nvim/
```

## Documentation

For comprehensive documentation on the package system, see:
- [Package Auto-Detection Guide](../docs/PACKAGE_AUTO_DETECTION.md)

## Troubleshooting

**Package not being installed?**
```bash
# Check if marker file exists
ls -la packages/YOUR_PACKAGE/.package

# If not, create it
touch packages/YOUR_PACKAGE/.package
```

**Stow conflicts?**
```bash
# Check what's conflicting
cd packages
stow --simulate --restow YOUR_PACKAGE

# Remove conflicting files/dirs manually, then restow
```

## See Also

- [GNU Stow Documentation](https://www.gnu.org/software/stow/manual/stow.html)
- [Hyprland Auto-Detection](../docs/HYPRLAND_AUTO_DETECTION.md) - Similar pattern

