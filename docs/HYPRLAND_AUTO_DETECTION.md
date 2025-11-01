# Hyprland Host Auto-Detection

## Overview

The package installation system now **automatically detects** which hosts need Hyprland packages, eliminating the need to manually maintain a hardcoded list in `install_deps.sh`.

## Problem Solved

**Before:** You had to remember to add new hostnames to the `hyprland_hosts` array in `install_deps.sh`:
```bash
local hyprland_hosts=("dragon" "spacedragon" "goldendragon")  # Easy to forget!
```

**After:** The script automatically detects Hyprland hosts using multiple detection methods.

## Detection Methods

The system checks hosts in this priority order:

### 1. Marker File (Recommended) ⭐

Create a `.hyprland` file in your host directory:

```bash
touch hosts/YOUR_HOST/.hyprland
```

**Why this is best:**
- ✅ Explicit and clear
- ✅ Fast detection
- ✅ Version controlled
- ✅ No parsing required

### 2. Auto-Detection from setup.sh

If `setup.sh` mentions these keywords, Hyprland packages are auto-installed:
- `hyprland`
- `hyprlock`
- `hypridle`
- `waybar`

### 3. Auto-Detection from Documentation

If documentation in `hosts/YOUR_HOST/docs/*.md` mentions Hyprland.

## Quick Start

### For New Hyprland Hosts

```bash
# Create host directory
mkdir -p hosts/$(hostname)

# Create Hyprland marker
touch hosts/$(hostname)/.hyprland

# Create setup script
cat > hosts/$(hostname)/setup.sh <<'EOF'
#!/bin/bash
set -e
echo "Setting up $(hostname)..."
# Your host-specific setup here
EOF

chmod +x hosts/$(hostname)/setup.sh
```

### For Existing Hosts

All existing Hyprland hosts already have marker files:
- ✅ `dragon/.hyprland`
- ✅ `firedragon/.hyprland`
- ✅ `goldendragon/.hyprland`
- ✅ `spacedragon/.hyprland`

## Verification

Check which hosts will receive Hyprland packages:

```bash
bash scripts/utilities/verify-hyprland-detection.sh
```

**Output example:**
```
HOST                 HYPRLAND        DETECTION METHOD                        
----                 --------        ----------------                        
dragon               ✓ Yes           marker                                  
firedragon           ✓ Yes           marker                                  
goldendragon         ✓ Yes           marker                                  
microdragon          ✗ No            not detected                            
spacedragon          ✓ Yes           marker                                  

Summary:
  Total hosts: 5
  Hyprland hosts: 4
  Non-Hyprland hosts: 1
```

## What Gets Installed for Hyprland Hosts

When auto-detected, these packages are installed:

### Desktop Environment (~70 packages)
- Hyprland, waybar, hyprlock, hypridle
- Swaync, swayosd, swaybg
- File managers, utilities, theming

### Applications (~25 AUR packages)
- Joplin, Kdenlive, LibreOffice
- Spotify, Zoom, Typora
- Calculators, clipboard managers

### Development Tools
- **Rust toolchain:** rustup, stable toolchain
- **Rust CLI tools:** lsd, bat, ripgrep, zoxide, eza, dua-cli, git-delta
- **Cursor IDE**

### Launchers
- Elephant launcher and plugins
- Walker, Impala

## Workflow

### Creating a New Hyprland Machine

```bash
# 1. Create host directory with marker
mkdir -p hosts/newmachine
touch hosts/newmachine/.hyprland

# 2. Create setup script
cat > hosts/newmachine/setup.sh <<'EOF'
#!/bin/bash
set -e

echo "Setting up newmachine..."

# Install NetBird
bash "$HOME/dotfiles/scripts/utilities/netbird-install.sh"

# Copy host-specific configs
sudo cp -rT "$HOME/dotfiles/hosts/newmachine/etc/" /etc/

# Restart services
sudo systemctl restart systemd-resolved

echo "Setup complete!"
EOF

chmod +x hosts/newmachine/setup.sh

# 3. Verify detection
bash scripts/utilities/verify-hyprland-detection.sh

# 4. Run installation
./setup.sh --host newmachine
```

### Creating a Non-Hyprland Machine

Simply omit the `.hyprland` marker file:

```bash
# Server/minimal setup - no Hyprland needed
mkdir -p hosts/server
cat > hosts/server/setup.sh <<'EOF'
#!/bin/bash
set -e
echo "Setting up server..."
# Server-specific setup only
EOF
chmod +x hosts/server/setup.sh
```

## Benefits

### ✅ Zero Maintenance
- No hardcoded arrays to update
- Add hosts by creating directories
- Detection is automatic

### ✅ Self-Documenting
- Marker files clearly indicate Hyprland support
- Verification script shows what will be installed
- Documentation explains the system

### ✅ Flexible
- Multiple detection methods
- Fallback to auto-detection if marker missing
- Easy to override

### ✅ Safe
- Explicit marker files prevent accidents
- Verification before installation
- Clear logging during detection

## Troubleshooting

### Host Not Detected as Hyprland

**Check detection:**
```bash
bash scripts/utilities/verify-hyprland-detection.sh
```

**Fix:**
```bash
# Add marker file
touch hosts/YOUR_HOST/.hyprland

# Verify
bash scripts/utilities/verify-hyprland-detection.sh
```

### Getting Hyprland Packages When You Don't Want Them

**Remove marker file:**
```bash
rm hosts/YOUR_HOST/.hyprland
```

**Or remove Hyprland mentions from setup.sh**

### Detection Not Working

**Debug:**
```bash
# Check marker file
ls -la hosts/YOUR_HOST/.hyprland

# Check setup.sh content
grep -i hyprland hosts/YOUR_HOST/setup.sh

# Check docs
find hosts/YOUR_HOST/docs -name "*.md" -exec grep -i hyprland {} +
```

## Technical Details

### Detection Function

The `is_hyprland_host()` function in `install_deps.sh`:

```bash
is_hyprland_host() {
    local hostname="$1"
    local host_dir="$HOSTS_DIR/$hostname"
    
    # Check marker files
    if [[ -f "$host_dir/.hyprland" ]] || [[ -f "$host_dir/HYPRLAND" ]]; then
        return 0  # Hyprland host
    fi
    
    # Check setup.sh
    if [[ -f "$host_dir/setup.sh" ]]; then
        if grep -qi "hyprland\|hyprlock\|hypridle\|waybar" "$host_dir/setup.sh"; then
            return 0  # Hyprland host
        fi
    fi
    
    # Check documentation
    if [[ -d "$host_dir/docs" ]]; then
        if find "$host_dir/docs" -type f -name "*.md" -exec grep -qi "hyprland" {} \; 2>/dev/null; then
            return 0  # Hyprland host
        fi
    fi
    
    return 1  # Not a Hyprland host
}
```

### Integration

Used in `install_for_arch()`:

```bash
# Old way (manual list):
local hyprland_hosts=("dragon" "spacedragon" "goldendragon")
if [[ " ${hyprland_hosts[*]} " =~ ${host} ]]; then

# New way (automatic):
if is_hyprland_host "$host"; then
```

## Migration Checklist

- [x] Create `.hyprland` marker files for existing hosts
- [x] Update `install_deps.sh` to use auto-detection
- [x] Create verification script
- [x] Document the system
- [x] Test detection logic

## See Also

- [Host Configuration README](../hosts/README.md) - General host setup guide
- [Verification Script](../scripts/utilities/verify-hyprland-detection.sh) - Test detection
- [Installation Script](../scripts/install/install_deps.sh) - Main installer

## References

- Inspired by the need for better ergonomics when adding new machines
- Follows the principle: "Configuration should be declarative, not imperative"
- Implements "Convention over Configuration" for common cases

