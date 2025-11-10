# Package Auto-Detection

## Overview

The dotfiles installation system _automatically detects_ which packages to install, eliminating the need to manually maintain a hardcoded list in `install.sh`.

## Detection Method

### Marker File (Simple and Explicit) ⭐

Create a `.package` file in your package directory:

```bash
touch packages/YOUR_PACKAGE/.package
```

**Why this works:**

- ✅ Explicit and clear intent
- ✅ Fast detection
- ✅ Version controlled
- ✅ No parsing or guessing required
- ✅ Easy to enable/disable packages

## Quick Start

### Adding a New Package

```bash
# 1. Create package directory with your dotfiles
mkdir -p packages/myapp/.config/myapp
echo "config content" > packages/myapp/.config/myapp/config.conf

# 2. Create package marker
touch packages/myapp/.package

# 3. Verify detection
bash scripts/utilities/verify-package-detection.sh

# 4. Install
./install.sh --dotfiles-only
```

### Disabling an Existing Package

```bash
# Simply remove the marker file
rm packages/PACKAGE_NAME/.package

# Verify
bash scripts/utilities/verify-package-detection.sh
```

### Re-enabling a Package

```bash
# Add the marker back
touch packages/PACKAGE_NAME/.package
```

## Existing Packages

All existing packages already have marker files:

- ✅ `alacritty/.package`
- ✅ `applications/.package`
- ✅ `dragon-cli/.package`
- ✅ `fastfetch/.package`
- ✅ `fcitx5/.package`
- ✅ `fonts/.package`
- ✅ `gh-extensions/.package`
- ✅ `git/.package`
- ✅ `gpg/.package`
- ✅ `gtk-3.0/.package`
- ✅ `gtk-4.0/.package`
- ✅ `hardware/.package`
- ✅ `hyprland/.package`
- ✅ `icons-in-terminal/.package`
- ✅ `kitty/.package`
- ✅ `lazygit/.package`
- ✅ `nvim/.package`
- ✅ `qt5ct/.package`
- ✅ `sddm/.package`
- ✅ `ssh/.package`
- ✅ `themes/.package`
- ✅ `tmux/.package`
- ✅ `typora/.package`
- ✅ `wlogout/.package`
- ✅ `xournalpp/.package`
- ✅ `zed/.package`
- ✅ `zsh/.package`

## Verification

Check which packages will be installed:

```bash
bash scripts/utilities/verify-package-detection.sh
```

**Output example:**

```bash
╔══════════════════════════════════════════════════════════════╗
║          Package Detection Verification                      ║
╚══════════════════════════════════════════════════════════════╝

Scanning packages directory: /home/user/dotfiles/packages

PACKAGE                   ENABLED         STATUS
-------                   -------         ------
alacritty                 ✓ Yes           will be installed
git                       ✓ Yes           will be installed
hyprland                  ✓ Yes           will be installed
my-disabled-pkg           ✗ No            marker file missing
nvim                      ✓ Yes           will be installed
...

Summary:
  Total packages: 28
  Enabled packages: 27
  Disabled packages: 1

27 package(s) will be installed via GNU Stow
```

## What Gets Installed

Packages are installed using [GNU Stow](https://www.gnu.org/software/stow/), which creates symlinks from `packages/PACKAGE_NAME/*` to your home directory.

### Example Package Structure

```bash
packages/
  myapp/
    .package          # Marker file enables installation
    .config/
      myapp/
        config.yaml   # → ~/.config/myapp/config.yaml
    .local/
      share/
        myapp/
          data.db     # → ~/.local/share/myapp/data.db
```

After installation, files are symlinked:

- `packages/myapp/.config/myapp/config.yaml` → `~/.config/myapp/config.yaml`
- `packages/myapp/.local/share/myapp/data.db` → `~/.local/share/myapp/data.db`

## Workflow

### Creating a New Package from Scratch

```bash
# 1. Create package directory
mkdir -p packages/mypackage/.config/mypackage

# 2. Add your configuration files
cat > packages/mypackage/.config/mypackage/config.conf <<'EOF'
# My package configuration
setting1 = value1
setting2 = value2
EOF

# 3. Enable the package
touch packages/mypackage/.package

# 4. Verify it will be installed
bash scripts/utilities/verify-package-detection.sh | grep mypackage

# 5. Install it
./install.sh --dotfiles-only

# 6. Verify symlinks were created
ls -la ~/.config/mypackage/
```

### Migrating Existing Config to a Package

```bash
# 1. Create package directory
mkdir -p packages/myapp

# 2. Move existing config into package
# (Structure must match final location in $HOME)
mv ~/.config/myapp packages/myapp/.config/

# 3. Enable package
touch packages/myapp/.package

# 4. Install (creates symlinks)
./install.sh --dotfiles-only

# Now ~/.config/myapp is a symlink to your dotfiles repo
ls -la ~/.config/myapp
# lrwxrwxrwx ... ~/.config/myapp -> ~/dotfiles/packages/myapp/.config/myapp
```

### Temporarily Disabling a Package

```bash
# Disable by removing marker
rm packages/somepackage/.package

# Unstow (remove symlinks)
cd packages && stow -D somepackage

# Later, re-enable
touch packages/somepackage/.package
./install.sh --dotfiles-only
```

## Benefits

### ✅ Zero Maintenance

- No hardcoded arrays to update in `install.sh`
- Add packages by creating directories + marker files
- Remove packages by deleting marker files
- Detection is automatic

### ✅ Self-Documenting

- Marker files clearly show which packages are enabled
- Verification script shows exactly what will be installed
- No need to read code to understand what's active

### ✅ Flexible

- Easy to experiment with new packages
- Disable packages temporarily without deleting them
- Clean separation of concerns

### ✅ Safe

- Explicit marker files prevent accidents
- Verification before installation
- Clear logging during installation

### ✅ Consistent with Existing Patterns

- Follows the same pattern as `.hyprland` host detection
- Uses familiar conventions
- Easy to understand if you know the host system

## Troubleshooting

### Package Not Being Installed

**Check detection:**

```bash
bash scripts/utilities/verify-package-detection.sh
```

**Fix:**

```bash
# Add marker file
touch packages/YOUR_PACKAGE/.package

# Verify
bash scripts/utilities/verify-package-detection.sh

# Install
./install.sh --dotfiles-only
```

### Package Still Being Installed When You Don't Want It

**Remove marker file:**

```bash
# Disable package
rm packages/YOUR_PACKAGE/.package

# Remove existing symlinks
cd packages
stow -D YOUR_PACKAGE
```

### No Packages Found

```bash
# Check if marker files exist
find packages -name ".package"

# If none exist, create them
cd packages
for dir in */; do
    if [ -d "$dir" ]; then
        touch "$dir/.package"
        echo "Created ${dir}.package"
    fi
done
```

### Stow Conflicts

If you get conflicts during installation:

```bash
# The script will show conflicts automatically, but you can manually check:
cd packages
stow --simulate --restow YOUR_PACKAGE

# Common fixes:
# 1. Remove conflicting file/directory
rm -rf ~/.config/YOUR_PACKAGE

# 2. Then restow
stow --restow YOUR_PACKAGE
```

## Technical Details

### Detection Function

The `setup_dotfiles()` function in `install.sh` automatically discovers packages:

```bash
# Auto-discover packages with .package marker file
local packages=()
while IFS= read -r -d '' package_file; do
    local package_dir=$(dirname "$package_file")
    local package_name=$(basename "$package_dir")
    packages+=("$package_name")
done < <(find "$PACKAGES_DIR" -maxdepth 2 -type f -name ".package" -printf "%p\0" 2>/dev/null | sort -z)
```

**How it works:**

1. Searches `packages/` directory for `.package` files
2. Extracts parent directory name as package name
3. Builds array of enabled packages
4. Iterates and instows each package

### Stow Integration

Each enabled package is installed using GNU Stow:

```bash
for package in "${packages[@]}"; do
    if [[ -d "$package" ]]; then
        log_info "Installing dotfiles package: $package"
        stow --restow -t "$HOME" "$package"
    fi
done
```

**Stow behavior:**

- `--restow`: Removes existing symlinks and recreates them (handles updates)
- `-t "$HOME"`: Target directory is your home folder
- Creates symlinks: `packages/PKG/.config/app/file` → `~/.config/app/file`

### File Structure Requirements

For stow to work correctly, your package structure must mirror the final location:

```bash
packages/
  mypackage/
    .package              # Marker (not stowed)
    .config/              # → ~/.config/
      myapp/
        config.yaml       # → ~/.config/myapp/config.yaml
    .local/               # → ~/.local/
      bin/
        myapp             # → ~/.local/bin/myapp
```

**Important:**

- Directories starting with `.` in packages are stowed as-is
- The `.package` marker file is **NOT** stowed (stow ignores it)
- Structure must exactly match final location in `$HOME`

## Integration with Install Script

The auto-detection seamlessly integrates with existing workflows:

```bash
# Install everything (packages + dotfiles)
./install.sh

# Install only dotfiles (uses auto-detection)
./install.sh --dotfiles-only

# Install specific host + dotfiles
./install.sh --host dragon
```

All these commands will automatically use the package auto-detection system.

## Best Practices

### 1. Always Create Marker Files for New Packages

```bash
# When creating a new package:
mkdir -p packages/mypackage/.config/mypackage
echo "config" > packages/mypackage/.config/mypackage/settings.conf
touch packages/mypackage/.package  # Don't forget this!
```

### 2. Verify Before Installing

```bash
# Always verify before running install:
bash scripts/utilities/verify-package-detection.sh
./install.sh --dotfiles-only
```

### 3. Keep Disabled Packages Without Deleting

```bash
# Instead of deleting a package you might want later:
rm packages/experimental-app/.package  # Just remove marker
# Keep the actual package directory for later
```

### 4. Document Package-Specific Setup

```bash
# Add README for complex packages:
cat > packages/mypackage/README.md <<'EOF'
# MyPackage Configuration

## Installation
Package is auto-detected via `.package` marker.

## Manual steps after install:
1. Run: mypackage --init
2. Configure: edit ~/.config/mypackage/config.yaml
EOF
```

### 5. Use Version Control

```bash
# Marker files should be committed:
git add packages/*/.package
git commit -m "Enable package auto-detection for all packages"
```

## See Also

- [Hyprland Auto-Detection](./HYPRLAND_AUTO_DETECTION.md) - Similar pattern for host detection
- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/stow.html) - How stow works
- [Verification Script](../scripts/utilities/verify-package-detection.sh) - Test package detection
