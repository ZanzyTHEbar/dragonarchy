# Host-Specific Configurations

This directory contains host-specific configurations for different machines in the dotfiles repository.

## Directory Structure

```bash
hosts/
├── dragon/          # Desktop workstation
├── firedragon/      # AMD laptop
├── goldendragon/    # Lenovo ThinkPad P16s Gen 4 (Intel) laptop (Type 21QV/21QW)
├── spacedragon/     # Asus Zenbook G14
└── microdragon/     # Raspberry pi
```

## Creating a New Host Configuration

### Basic Setup

1. Create a directory with your machine's hostname:

   ```bash
   mkdir -p hosts/$(hostname)
   ```

2. Add a `setup.sh` script for host-specific setup:

   ```bash
   cat > hosts/$(hostname)/setup.sh <<'EOF'
   #!/bin/bash
   set -e
   echo "Running setup for $(hostname)..."
   # Add your host-specific setup here
   EOF
   chmod +x hosts/$(hostname)/setup.sh
   ```

### Hyprland Configuration

The package installation script automatically detects if a host needs Hyprland packages using multiple methods:

#### Method 1: Marker File (Recommended)

Create a `.hyprland` marker file in your host directory:

```bash
touch hosts/$(hostname)/.hyprland
```

This is the most explicit and reliable method.

#### Method 2: Automatic Detection from setup.sh

If your `setup.sh` mentions any of these keywords, Hyprland packages will be installed automatically:

- `hyprland`
- `hyprlock`
- `hypridle`
- `waybar`

#### Method 3: Automatic Detection from Documentation

If you have documentation in `hosts/$(hostname)/docs/*.md` that mentions Hyprland, it will be detected.

### What Gets Installed for Hyprland Hosts

When a host is detected as a Hyprland host, it receives:

1. **Hyprland Desktop Environment** (~70 packages)
   - Hyprland, waybar, hyprlock, hypridle
   - Swaync, swayosd, swaybg
   - File managers, launchers, utilities

2. **Development Tools** (~25 AUR packages)
   - IDEs and editors
   - Media tools (Kdenlive, Spotify, etc.)
   - Utilities (calculator, clipboard managers, etc.)

3. **Rust Toolchain and Tools**
   - rustup, stable toolchain
   - CLI tools: lsd, bat, ripgrep, zoxide, eza, dua-cli, git-delta

4. **Additional Software**
   - Cursor IDE
   - Elephant launcher and plugins

## Host-Specific Files

### Required Files

- `setup.sh` - Host-specific setup script (recommended)

### Optional Files

- `.hyprland` - Marker file for Hyprland support (recommended for Hyprland hosts)
- `HYPRLAND` - Alternative marker file name
- `docs/` - Documentation directory
- `etc/` - System configuration files (will be copied to `/etc/`)

## Examples

### Desktop Workstation (Hyprland)

```bash
hosts/dragon/
├── .hyprland              # Marker file
├── setup.sh               # Host setup script
├── dynamic_led.py         # Custom scripts
├── dynamic_led.service    # Systemd services
└── etc/                   # System configs
    └── systemd/
        └── resolved.conf.d/
            └── dns.conf
```

### Laptop (Hyprland)

```bash
hosts/firedragon/
├── .hyprland              # Marker file
├── setup.sh               # Extensive laptop setup
├── docs/                  # Documentation
│   ├── GESTURES_QUICKSTART.md
│   ├── ADVANCED_GESTURES.md
│   └── SETUP_SUMMARY.md
└── etc/                   # System configs
    └── systemd/
        └── resolved.conf.d/
            └── dns.conf
```

### Minimal Server (No Hyprland)

```bash
hosts/microdragon/
└── setup.sh               # Basic setup only
```

## Verification

To check which hosts will be detected as Hyprland hosts:

```bash
cd ~/dotfiles
for host in hosts/*/; do
    hostname=$(basename "$host")
    if [[ -f "$host/.hyprland" ]] || [[ -f "$host/HYPRLAND" ]]; then
        echo "✓ $hostname - Hyprland (marker file)"
    elif [[ -f "$host/setup.sh" ]] && grep -qi "hyprland\|waybar" "$host/setup.sh"; then
        echo "✓ $hostname - Hyprland (auto-detected from setup.sh)"
    else
        echo "✗ $hostname - No Hyprland"
    fi
done
```

## Best Practices

1. **Always create a marker file** - Use `.hyprland` for Hyprland hosts to make it explicit
2. **Document your setup** - Add a README or docs explaining host-specific configurations
3. **Keep setup.sh idempotent** - Scripts should be safe to run multiple times
4. **Test on a fresh install** - Verify your setup works on a clean system
5. **Separate concerns** - Use `etc/` for system configs, keep scripts in the root

## Migration Guide

If you have an existing host configuration without a marker file, add one:

```bash
# For Hyprland hosts
touch hosts/YOUR_HOSTNAME/.hyprland

# Verify detection
grep -qi "hyprland" hosts/YOUR_HOSTNAME/setup.sh && echo "Will auto-detect" || echo "Needs marker file"
```

## Troubleshooting

### Host not detected as Hyprland

1. Check if marker file exists: `ls -la hosts/YOUR_HOST/.hyprland`
2. Check setup.sh mentions Hyprland: `grep -i hyprland hosts/YOUR_HOST/setup.sh`
3. Manually add marker file: `touch hosts/YOUR_HOST/.hyprland`

### Wrong packages installed

If you're getting Hyprland packages but don't want them:

1. Remove `.hyprland` marker file
2. Remove Hyprland mentions from setup.sh
3. Re-run the installation

### Host-specific setup not running

1. Verify setup.sh is executable: `chmod +x hosts/YOUR_HOST/setup.sh`
2. Check for syntax errors: `bash -n hosts/YOUR_HOST/setup.sh`
3. Run manually: `bash hosts/YOUR_HOST/setup.sh`
