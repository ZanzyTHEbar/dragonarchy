# Host-Specific Configurations

This directory contains host-specific configurations for different machines in the dotfiles repository.

## Directory Structure

```bash
hosts/
├── dragon/          # AMD desktop workstation (AIO cooler, LED control)
├── firedragon/      # ASUS VivoBook AMD laptop
├── goldendragon/    # Lenovo ThinkPad P16s (Intel/NVIDIA)
├── microdragon/     # Raspberry Pi
└── shared/          # Shared host resources
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

### Trait Files (Recommended)

Each host can declare its capabilities via a `.traits` file. This drives validation, detection, and future automation:

```bash
cat > hosts/$(hostname)/.traits <<'EOF'
# One trait per line. Lines starting with # are comments.
desktop
hyprland
laptop
tlp
EOF
```

Available traits and what they control:

| Trait | Effect |
|-------|--------|
| `desktop` | Validates systemd-resolved |
| `hyprland` | Detects Hyprland host, validates Hyprland components |
| `laptop` | Checks brightnessctl |
| `tlp` | Checks TLP + masks systemd-rfkill |
| `aio-cooler` | Validates liquidctl + cooler/LED services |
| `asus` | Checks asusd service |
| `nvidia` | (Future) NVIDIA-specific checks |
| `amd-gpu` | (Future) AMD GPU checks |
| `fingerprint` | Checks fprintd |
| `netbird` | (Future) NetBird VPN checks |

### System Modifications Safety Layer

All host setup scripts use `system-mods.sh` for privileged operations. **Never use raw `sudo` in host scripts.** Instead:

```bash
source "${SCRIPTS_DIR}/lib/system-mods.sh"

# Install a config file (with automatic backup + idempotency)
sysmod_install_file "./my.conf" /etc/myapp/my.conf 644

# Write content to a system file
sysmod_tee_file /etc/sysctl.d/99-custom.conf "vm.swappiness = 10"

# Enable and start a systemd service
sysmod_ensure_service "my-daemon.service" "./my-daemon.service"

# Run any command with sudo
_sysmod_sudo systemctl daemon-reload
```

All modifications create timestamped backups under `/etc/.dragonarchy-backups/` and skip operations when content hasn't changed. Set `SYSMOD_DRY_RUN=1` to preview changes.

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

- `.traits` - Host capability declarations (recommended; drives validation and detection)
- `.hyprland` - Legacy marker file for Hyprland support (prefer `.traits` with `hyprland` trait)
- `HYPRLAND` - Alternative legacy marker file name
- `docs/` - Documentation directory
- `etc/` - System configuration files (deployed to `/etc/` via `sysmod_install_dir`)

## Examples

### Desktop Workstation (Hyprland)

```bash
hosts/dragon/
├── .traits                # amd-gpu, aio-cooler, hyprland, desktop, netbird
├── .hyprland              # Legacy marker file
├── setup.sh               # Host setup script (uses sysmod_* helpers)
├── dynamic_led.py         # Custom LED control script
├── dynamic_led.service    # Systemd services
├── liquidctl-dragon.service
└── etc/                   # System configs (deployed via sysmod_install_dir)
    └── systemd/
        └── resolved.conf.d/
            └── dns.conf
```

### Laptop (Hyprland)

```bash
hosts/firedragon/
├── .traits                # laptop, amd-gpu, tlp, hyprland, desktop, asus, netbird
├── .hyprland              # Legacy marker file
├── setup.sh               # Extensive laptop setup (uses sysmod_* helpers)
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

To check host traits and Hyprland detection:

```bash
cd ~/dotfiles
for host in hosts/*/; do
    hostname=$(basename "$host")
    [[ "$hostname" == "shared" ]] && continue

    traits=""
    if [[ -f "$host/.traits" ]]; then
        traits=$(grep -v '^#' "$host/.traits" | grep -v '^$' | paste -sd, -)
    fi

    if [[ -f "$host/.traits" ]] && grep -q "^hyprland$" "$host/.traits"; then
        echo "✓ $hostname - Hyprland (trait) [$traits]"
    elif [[ -f "$host/.hyprland" ]] || [[ -f "$host/HYPRLAND" ]]; then
        echo "✓ $hostname - Hyprland (marker file) [$traits]"
    elif [[ -f "$host/setup.sh" ]] && grep -qi "hyprland\|waybar" "$host/setup.sh"; then
        echo "✓ $hostname - Hyprland (auto-detected) [$traits]"
    else
        echo "✗ $hostname - No Hyprland [$traits]"
    fi
done
```

Or use the validation script for a thorough check:

```bash
./scripts/install/validate.sh --host dragon       # Check specific host
./scripts/install/validate.sh --json | jq .status  # Quick CI check
```

## Best Practices

1. **Always create a `.traits` file** - Declare host capabilities for validation and detection
2. **Use `sysmod_*` helpers** - Never use raw `sudo` in setup scripts; always go through `system-mods.sh`
3. **Gate with `install-state`** - Wrap every non-trivial operation in `is_step_completed`/`mark_step_completed`
4. **Document your setup** - Add a README or docs explaining host-specific configurations
5. **Keep setup.sh idempotent** - Scripts should be safe to run multiple times
6. **Test on a fresh install** - Verify your setup works on a clean system
7. **Separate concerns** - Use `etc/` for system configs, keep scripts in the root

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
