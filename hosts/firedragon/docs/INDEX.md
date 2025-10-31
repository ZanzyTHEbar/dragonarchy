# FireDragon Host - Documentation Index

## Quick Links

- [Main README](./README.md) - Comprehensive host documentation
- [Limine Setup Guide](./LIMINE_SETUP.md) - **Bootloader-specific quick start**
- [Setup Summary](./SETUP_SUMMARY.md) - What gets installed and configured
- [Asus VivoBook Features](./ASUS_VIVOBOOK_FEATURES.md) - Asus-specific hardware support
- [MT7902 WiFi Setup](./MT7902_WIFI_SETUP.md) - MediaTek WiFi driver guide
- [Gesture Quickstart](./GESTURES_QUICKSTART.md) - Quick gesture setup
- [Advanced Gestures](./ADVANCED_GESTURES.md) - Plugin-based gesture features

## Setup Scripts

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `setup.sh` | Main host setup | First time setup & updates |
| `setup-mt7902-wifi.sh` | MT7902 WiFi driver | Only if WiFi not working |
| `setup-mt7902-bluetooth.sh` | MT7902 Bluetooth driver | Only if Bluetooth not working |
| `enable-advanced-gestures.sh` | Advanced gesture plugins | After plugins installed |

## By Topic

### First Time Setup
1. Read: [LIMINE_SETUP.md](./LIMINE_SETUP.md) - **Start here for Limine users!**
2. Or read: [SETUP_SUMMARY.md](./SETUP_SUMMARY.md) for detailed overview
3. Run: `bash setup.sh`
4. Follow post-setup instructions in terminal output
5. Reboot to apply changes
6. Verify ACPI parameters: `cat /proc/cmdline | grep acpi_osi`
7. Optional: Setup MT7902 WiFi if needed
8. Optional: Enable advanced gestures

### Asus VivoBook Specific
- **Quick Start**: [LIMINE_SETUP.md](./LIMINE_SETUP.md) - Limine bootloader guide
- **Hardware Support**: [ASUS_VIVOBOOK_FEATURES.md](./ASUS_VIVOBOOK_FEATURES.md)
  - Keyboard backlight control
  - ACPI fixes (Limine/systemd-boot/GRUB)
  - Special function keys
  - WMI driver configuration

### WiFi (MT7902)
- **Driver Setup**: [MT7902_WIFI_SETUP.md](./MT7902_WIFI_SETUP.md)
  - Community WiFi driver installation
  - Bluetooth driver installation
  - DKMS integration
  - Troubleshooting
  - Alternative solutions

### Touchpad Gestures
- **Quick Start**: [GESTURES_QUICKSTART.md](./GESTURES_QUICKSTART.md)
  - Basic 3-finger & 4-finger swipes
  - Quick setup commands
- **Advanced**: [ADVANCED_GESTURES.md](./ADVANCED_GESTURES.md)
  - Plugin-based gestures
  - Edge swipes
  - Pinch gestures

### Hardware Optimization
- **AMD Graphics**: See [README.md](./README.md#amd-graphics-optimization)
- **Power Management**: See [README.md](./README.md#power-management-tlp)
- **Battery**: See [README.md](./README.md#battery-management)
- **Thermal**: See [README.md](./README.md#thermal-management)

## Quick Command Reference

### Asus VivoBook
```bash
kbd-backlight up|down|toggle  # Keyboard backlight control
```

### WiFi
```bash
bash ~/dotfiles/hosts/firedragon/setup-mt7902-wifi.sh  # Install MT7902 WiFi driver
nmcli device wifi list                                 # List WiFi networks
ip link show                                           # Check interfaces
```

### Bluetooth
```bash
bash ~/dotfiles/hosts/firedragon/setup-mt7902-bluetooth.sh  # Install MT7902 Bluetooth driver
bluetoothctl list                                           # List Bluetooth controllers
hciconfig                                                   # Show adapter info
systemctl status bluetooth                                  # Check service status
```

### Gestures
```bash
libinput list-devices                   # List input devices
libinput debug-events                   # Watch gestures live
vim ~/.config/hypr/config/gestures.conf # Edit gesture config
```

### Power & Battery
```bash
battery          # Battery status
powersave        # Switch to power-save mode
powerperf        # Switch to performance mode
temp             # System temperatures
gpuinfo          # AMD GPU info
```

## Troubleshooting

| Issue | Documentation |
|-------|---------------|
| WiFi not working | [MT7902_WIFI_SETUP.md](./MT7902_WIFI_SETUP.md#troubleshooting) |
| Gestures not working | [ASUS_VIVOBOOK_FEATURES.md](./ASUS_VIVOBOOK_FEATURES.md#gesture-not-working) |
| Keyboard backlight | [ASUS_VIVOBOOK_FEATURES.md](./ASUS_VIVOBOOK_FEATURES.md#keyboard-backlight-not-working) |
| ACPI errors | [ASUS_VIVOBOOK_FEATURES.md](./ASUS_VIVOBOOK_FEATURES.md#acpi-errors-in-dmesg) |
| Battery issues | [README.md](./README.md#troubleshooting) |

## Architecture

FireDragon follows the repository's host-specific pattern:

```
hosts/firedragon/
├── setup.sh                          # Main setup script
├── setup-mt7902-wifi.sh             # MT7902 WiFi driver setup
├── setup-mt7902-bluetooth.sh        # MT7902 Bluetooth driver setup
├── enable-advanced-gestures.sh      # Advanced gesture enabler
├── README.md                        # Main documentation
├── LIMINE_SETUP.md                  # Limine bootloader quick start
├── ASUS_VIVOBOOK_FEATURES.md        # Asus-specific docs
├── MT7902_WIFI_SETUP.md             # WiFi & Bluetooth driver docs
├── GESTURES_QUICKSTART.md           # Gesture quick start
├── ADVANCED_GESTURES.md             # Advanced gesture docs
├── SETUP_SUMMARY.md                 # Setup summary
├── INDEX.md                         # This file
└── etc/                             # System configurations
    ├── tlp.d/                       # TLP power management
    ├── modprobe.d/                  # Kernel module options
    ├── systemd/                     # Systemd configurations
    └── (no grub.d for Limine users)
```

## Integration with Main Repository

### Hyprland Configuration
- Desktop hosts: Empty `~/.config/hypr/config/host-config.conf`
- Laptop hosts: `host-config.conf` sources `gestures.conf`
- Main config: Sources `host-config.conf` conditionally

### Shell Configuration
- Host-specific: `~/.zshrc.firedragon`
- Sourced by main: `~/.zshrc`
- Contains power management aliases and functions

### Package Management
- Host packages: Managed by `setup.sh`
- Shared packages: Managed by main install scripts
- Stow integration: Laptop-specific dotfiles

## Repository Patterns

FireDragon demonstrates these patterns:

1. **Conditional Loading**: Host-specific configs loaded only when needed
2. **Safety Checks**: All scripts check prerequisites before running
3. **Modular Setup**: Separate functions for each component
4. **DKMS Integration**: Automatic driver rebuilds on kernel updates
5. **Documentation First**: Comprehensive docs for all features

## Contributing

When adding features to FireDragon:

1. Add setup logic to `setup.sh`
2. Create dedicated docs for complex features
3. Update this index
4. Follow repository patterns (see above)
5. Test on clean install

## Support Resources

- **Arch Wiki**: https://wiki.archlinux.org/
- **Asus Laptops**: https://wiki.archlinux.org/title/ASUS
- **TLP**: https://wiki.archlinux.org/title/TLP
- **Hyprland**: https://wiki.hyprland.org/
- **MT76 Driver**: https://wireless.wiki.kernel.org/en/users/drivers/mt76

---

**Last Updated**: October 31, 2024
**Status**: Complete - All features documented
**Tested**: Asus VivoBook, AMD Radeon, MT7902, CachyOS

