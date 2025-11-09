# Hyprland Package

This package contains Hyprland window manager configurations and system-level setup files.

## Structure

### User Configurations (Stowed to ~/)
- `.config/hypr/` - Main Hyprland configuration directory
  - `hyprland.conf` - Main Hyprland configuration
  - `config/` - Modular configuration files
    - `hypridle.conf` - Idle management configuration
    - `hyprlock.conf` - Screen locker configuration
    - `animations.conf` - Animation settings
    - `decorations.conf` - Window decoration settings
    - `input.conf` - Input device configuration
    - `keybinds.conf` - Keyboard shortcuts
    - `monitor.conf` - Display configuration
    - `theme.conf` - Theme settings
    - `windowrules.conf` - Window management rules
    - Other configuration modules...

### System Configurations
- `hyprlock.pam` - PAM authentication configuration for hyprlock (installed by system-config.sh)

## Setup Process

### 1. Package Installation
The hyprland package is installed during the main setup process via GNU Stow:

```bash
# This happens automatically during ./setup.sh
stow -t ~/ hyprland
```

### 2. System Configuration
System-level configurations (PAM) are installed via the system configuration script:

```bash
# This runs automatically if you have sudo privileges
sudo ./scripts/install/system-config.sh
```

### 3. Manual Setup (if needed)
If you need to manually set up the PAM configuration:

```bash
sudo cp packages/hyprland/hyprlock.pam /etc/pam.d/hyprlock
sudo chmod 644 /etc/pam.d/hyprlock
```

## Features

### Hypridle (Idle Management)
- **Screen dimming** after 5 minutes of inactivity
- **Screen locking** after 10 minutes of inactivity
- **System suspend** after 30 minutes of inactivity
- Configurable via `~/.config/hypr/config/hypridle.conf`

### Hyprlock (Screen Locker)
- **PAM authentication** for secure unlocking
- **Theme integration** with current Hyprland theme
- **Graceful fallback** if authentication fails
- Configurable via `~/.config/hypr/config/hyprlock.conf`

## Troubleshooting

### Common Issues

1. **Hyprlock password rejection**:
   - Ensure PAM configuration is installed: `ls /etc/pam.d/hyprlock`
   - Check PAM configuration: `cat /etc/pam.d/hyprlock`
   - Restart hypridle: `pkill hypridle && uwsm app -- hypridle`

2. **Hypridle not starting**:
   - Check configuration: `cat ~/.config/hypr/config/hypridle.conf`
   - Verify hypridle is installed: `which hypridle`
   - Check logs: `journalctl -u hypridle` (if running as service)

3. **Sleep/suspend not working**:
   - Check systemd services: `systemctl status sleep.target suspend.target`
   - Verify logind configuration: `cat /etc/systemd/logind.conf`
   - Test manual suspend: `systemctl suspend`

### Debug Tools

Run the debug script to diagnose issues:

```bash
./scripts/theme-manager/debug-hypridle
```

### Manual Testing

Test individual components:

```bash
# Test hyprlock manually
hyprlock

# Test hypridle configuration
hypridle -c ~/.config/hypr/config/hypridle.conf

# Test suspend manually
systemctl suspend
```

## Customization

### Modifying Idle Behavior
Edit `~/.config/hypr/config/hypridle.conf`:

```bash
# Change timeout values (in seconds)
timeout = 300    # 5 minutes for screen dim
timeout = 600    # 10 minutes for screen lock
timeout = 1800   # 30 minutes for suspend
```

### Modifying Lock Screen
Edit `~/.config/hypr/config/hyprlock.conf`:

```bash
# Customize appearance
background {
    color = rgba(0, 0, 0, 0.8)
}

input-field {
    size = 400, 50
    # ... other options
}
```

### Modifying PAM Configuration
Edit `/etc/pam.d/hyprlock` (requires sudo):

```bash
# Add additional authentication methods
auth    sufficient pam_fprintd.so  # Fingerprint
auth    required   pam_unix.so      # Password
```

## Integration

This package integrates with:
- **Theme system** - Colors and themes are applied automatically
- **Hardware detection** - Different configurations for different hardware
- **System services** - Automatic service management
- **User permissions** - Proper group memberships for hardware access

## Dependencies

- `hyprland` - Window manager
- `hypridle` - Idle management daemon
- `hyprlock` - Screen locker
- `pam` - Pluggable Authentication Modules
- `systemd` - Service management
