# FireDragon MT7902 WiFi & Bluetooth Setup Guide

## Overview

The Asus VivoBook FireDragon laptop uses the MediaTek MT7902 WiFi 6E chip, which currently lacks official Linux kernel support. This guide provides automated setup for both WiFi and Bluetooth community-developed drivers.

## Current Status

**MT7902 WiFi Support**: ⚠️ Community drivers only (no official kernel support yet)  
**MT7902 Bluetooth Support**: ⚠️ Requires custom kernel module compilation

**Safety Checks Built-in**:

- ✅ Detects if MT7902 chip is present
- ✅ Checks if WiFi/Bluetooth already working
- ✅ Backs up current configuration
- ✅ **DKMS integration** for automatic kernel rebuild (WiFi & Bluetooth)
- ✅ Safe fallback if DKMS fails
- ✅ Rollback support for Bluetooth

## Quick Start

### Check WiFi & Bluetooth Status

```bash
# Check if MT7902 is present
lspci -nn | grep -i "14c3\|network"
lsusb | grep -i "mediatek\|0e8d"

# Check if WiFi interface exists
ip link show | grep -E "wlan|wlp"
nmcli device

# Check if Bluetooth is working
hciconfig
bluetoothctl list
systemctl status bluetooth
```

### Install WiFi Driver (If Needed)

```bash
cd ~/dotfiles/hosts/firedragon
bash setup-mt7902-wifi.sh
```

### Install Bluetooth Driver (If Needed)

**Important**: Only run this if Bluetooth is NOT working after WiFi driver installation.

```bash
cd ~/dotfiles/hosts/firedragon
bash setup-mt7902-bluetooth.sh
```

**Note**: Bluetooth setup requires kernel headers and may take longer than WiFi setup due to compilation.

## WiFi Driver Installation

The WiFi setup script will:

1. Detect MT7902 chip
2. Check if WiFi already works (skip if working)
3. Install build dependencies
4. Clone driver repository
5. Build and install driver
6. Setup DKMS for automatic rebuilds
7. Install firmware files
8. Configure module loading

## What Gets Installed

### Build Dependencies

- `base-devel` - Build tools
- `linux-headers` - Kernel headers for your kernel
- `dkms` - Dynamic Kernel Module Support
- `git` - For cloning driver repo
- `bc`, `iw`, `wireless_tools`, `wpa_supplicant` - WiFi utilities

### Driver Components

- MT76 driver framework
- MT7902-specific modules
- Firmware files (in `/lib/firmware/mediatek/`)
- DKMS configuration for auto-rebuild

### Configuration Files

- `/etc/modprobe.d/mt7902.conf` - Module loading configuration
- `/etc/modules-load.d/mt7902.conf` - Load at boot
- `/usr/src/mt7902-1.0/` - DKMS source (if DKMS setup succeeds)

## Safety Features

### Pre-Installation Checks

```bash
# 1. Check for MT7902 chip
if ! lspci -nn | grep -qi "14c3:0608\|14c3:7902"; then
    echo "MT7902 not detected, skipping"
    exit 0
fi

# 2. Check if WiFi already works
if ip link show | grep -q "wlan"; then
    echo "WiFi already working, installation not needed"
    exit 0
fi
```

### Backup

The script automatically backs up:

- NetworkManager configuration
- Location: `~/.config/mt7902_backup/`

### Rollback

If driver causes issues:

```bash
# Remove DKMS module
sudo dkms remove mt7902/1.0 --all

# Remove modules
sudo modprobe -r mt7902 mt792x-lib mt792x-usb

# Remove from autoload
sudo rm /etc/modules-load.d/mt7902.conf

# Restore backup
cp -r ~/.config/mt7902_backup/NetworkManager /etc/
sudo systemctl restart NetworkManager
```

## DKMS Integration

### What is DKMS?

DKMS (Dynamic Kernel Module Support) automatically rebuilds the driver when you update your kernel, so you don't have to manually reinstall after each kernel update.

### Verify DKMS Status

```bash
# Check if DKMS module is installed
dkms status

# Should show:
# mt7902/1.0, 6.x.x-x-MANJARO, x86_64: installed
```

### Manual DKMS Commands

```bash
# Rebuild driver
sudo dkms build mt7902/1.0
sudo dkms install mt7902/1.0

# Remove driver
sudo dkms remove mt7902/1.0 --all
```

## Troubleshooting

### WiFi Not Appearing After Installation

**1. Check if modules loaded**:

```bash
lsmod | grep mt7902
lsmod | grep mt792x
```

**2. Check kernel logs**:

```bash
dmesg | grep -i mt7902
dmesg | grep -i firmware
```

**3. Check for firmware files**:

```bash
ls -la /lib/firmware/mediatek/
```

**4. Manually load modules**:

```bash
sudo modprobe mt76-connac-lib
sudo modprobe mt76
sudo modprobe mt792x-lib
sudo modprobe mt792x-usb
sudo modprobe mt7902
```

**5. Check interface**:

```bash
ip link show
iwconfig
```

### Driver Build Failed

**Check build logs**:

```bash
cd ~/.local/src/mt7902_driver/mt76
make clean
make 2>&1 | tee build.log
```

**Common issues**:

- Missing kernel headers: `sudo pacman -S linux-headers`
- Wrong kernel version: Ensure headers match your running kernel
- Build tools missing: `sudo pacman -S base-devel`

### DKMS Failed

If DKMS setup fails, the script falls back to manual module loading. This works but won't survive kernel updates.

**To retry DKMS**:

```bash
cd ~/dotfiles/hosts/firedragon
bash setup-mt7902-wifi.sh
```

### WiFi Unstable or Slow

**Check signal strength**:

```bash
iwconfig  # Look at Link Quality
```

**Try power management off**:

```bash
sudo iwconfig wlan0 power off
```

**Check for errors**:

```bash
journalctl -f | grep -i wlan
```

## Kernel Updates

### With DKMS (Recommended)

DKMS automatically rebuilds the driver:

```bash
sudo pacman -Syu  # Update system including kernel
sudo reboot       # DKMS rebuilds driver automatically
```

### Without DKMS

After kernel update, re-run setup:

```bash
cd ~/dotfiles/hosts/firedragon
bash setup-mt7902-wifi.sh
```

## Alternative Solutions

### 1. USB WiFi Adapter

If MT7902 driver doesn't work well, consider a USB WiFi adapter:

**Recommended models** (good Linux support):

- TP-Link Archer T3U / T4U (Realtek RTL8812AU)
- Intel AX200/AX210 (if M.2 slot available)
- Alfa AWUS036ACH (high power, monitor mode)

### 2. Replace WiFi Card

The MT7902 card can be replaced with a better-supported card:

**Recommended replacements**:

- **Intel AX210** - Excellent Linux support, WiFi 6E, Bluetooth 5.2
- **Intel AX200** - Good Linux support, WiFi 6, Bluetooth 5.0
- Check laptop's M.2 WiFi slot (usually M.2 2230 or CNVi)

### 3. Wait for Official Support

Monitor these resources for official kernel support:

- [Linux kernel mailing list](https://lore.kernel.org/linux-wireless/)
- [MediaTek GitHub](https://github.com/openwrt/mt76)
- Arch Linux forums

## Technical Details

### Driver Source

- **Repository**: <https://github.com/OnlineLearningTutorials/mt7902_temp>
- **Based on**: MT76 driver framework
- **Status**: Community-developed, in progress
- **Stability**: ⚠️ Experimental (use at your own risk)

### Module Dependencies

```bash
mt7902
  ├── mt792x-lib
  ├── mt792x-usb
  ├── mt76x02-lib
  ├── mt76x02-usb
  ├── mt76
  ├── mt76-usb
  ├── mt76-sdio
  └── mt76-connac-lib
```

### PCI IDs

- `14c3:0608` - MT7902 WiFi 6E
- `14c3:7902` - MT7902 variant

## Files Created/Modified

### Created by Script

- `~/.local/src/mt7902_driver/` - Driver source
- `~/.config/mt7902_backup/` - Backup of network config
- `/etc/modprobe.d/mt7902.conf` - Module configuration
- `/etc/modules-load.d/mt7902.conf` - Load at boot
- `/lib/firmware/mediatek/*` - Firmware files
- `/usr/src/mt7902-1.0/` - DKMS source (if applicable)

### Commands Added

None - driver loads automatically via modules-load.d

## Uninstallation

### WiFi Driver Uninstallation

To remove MT7902 WiFi driver:

```bash
# Remove DKMS module
sudo dkms remove mt7902/1.0 --all

# Remove kernel modules
sudo modprobe -r mt7902 mt792x-lib mt792x-usb

# Remove configuration
sudo rm /etc/modprobe.d/mt7902.conf
sudo rm /etc/modules-load.d/mt7902.conf

# Remove source
rm -rf ~/.local/src/mt7902_driver

# Restore backup (optional)
sudo cp -r ~/.config/mt7902_backup/NetworkManager /etc/
sudo systemctl restart NetworkManager

# Reboot
sudo reboot
```

### Bluetooth Driver Uninstallation

To remove MT7902 Bluetooth driver:

```bash
# Run rollback script
cd ~/dotfiles/hosts/firedragon
bash setup-mt7902-bluetooth.sh --rollback

# Reboot
sudo reboot
```

## MT7902 Bluetooth Setup

### Overview

The MT7902 chip includes Bluetooth functionality, but requires separate setup from WiFi. The Bluetooth driver is built from your kernel source.

### Requirements

- Kernel headers installed: `sudo pacman -S linux-headers`
- Build tools: `base-devel`, `bluez`, `bluez-utils`
- Working kernel source at `/usr/lib/modules/$(uname -r)/build`

### Installation Process

The Bluetooth setup script (`setup-mt7902-bluetooth.sh`) will:

1. Check if MT7902 Bluetooth chip is present
2. Verify Bluetooth is not already working
3. Install required dependencies (`bluez`, `bluez-utils`, `pahole`)
4. Copy Bluetooth driver source from kernel
5. Compile `btmtk.ko` and `btusb.ko` modules
6. Backup existing Bluetooth modules
7. **Setup DKMS for automatic rebuilds** (with fallback to manual)
8. Install custom modules to `/lib/modules/$(uname -r)/updates/`
9. Load modules and enable Bluetooth service
10. Configure modules to load at boot

### Run Bluetooth Setup

```bash
cd ~/dotfiles/hosts/firedragon
bash setup-mt7902-bluetooth.sh
```

### Safety Features

- **Pre-checks**: Detects chip and verifies Bluetooth status
- **Backups**: Saves original `btmtk.ko` and `btusb.ko` modules
- **Rollback**: Includes `--rollback` option to restore originals
- **Non-destructive**: Installs to `updates/` directory (higher priority than system modules)
- **DKMS Integration**: ✅ **NEW!** Automatically rebuilds drivers on kernel updates

### Post-Installation

After running the Bluetooth setup:

1. **Reboot your system**:

   ```bash
   sudo reboot
   ```

2. **Verify Bluetooth adapter**:

   ```bash
   hciconfig
   # Should show hci0 device
   
   bluetoothctl list
   # Should show controller
   ```

3. **Test Bluetooth**:

   ```bash
   bluetoothctl
   # In bluetoothctl prompt:
   power on
   agent on
   default-agent
   scan on
   # Should see nearby Bluetooth devices
   ```

### Bluetooth Usage

**Using bluetoothctl (CLI)**:

```bash
bluetoothctl                          # Enter Bluetooth control
power on                              # Power on adapter
agent on                              # Enable agent
default-agent                         # Set as default
scan on                               # Scan for devices
devices                               # List found devices
pair <MAC_ADDRESS>                    # Pair with device
connect <MAC_ADDRESS>                 # Connect to device
trust <MAC_ADDRESS>                   # Trust device (auto-connect)
```

**Check status**:

```bash
hciconfig                             # Show adapter info
hciconfig hci0 up                     # Bring adapter up (if down)
systemctl status bluetooth            # Service status
lsmod | grep bt                       # Check loaded modules
```

### Troubleshooting Bluetooth

**Bluetooth adapter not found**:

```bash
# Check if modules loaded
lsmod | grep btmtk
lsmod | grep btusb

# Manually load modules
sudo modprobe btmtk
sudo modprobe btusb

# Check dmesg for errors
dmesg | grep -i bluetooth
dmesg | grep -i btusb
```

**Service not starting**:

```bash
# Check service status
sudo systemctl status bluetooth

# Restart service
sudo systemctl restart bluetooth

# Enable service
sudo systemctl enable bluetooth
```

**Devices not pairing**:

```bash
# Remove device and try again
bluetoothctl remove <MAC_ADDRESS>

# Check rfkill
rfkill list bluetooth
sudo rfkill unblock bluetooth

# Power cycle adapter
bluetoothctl power off
bluetoothctl power on
```

**Rollback to original modules**:

```bash
cd ~/dotfiles/hosts/firedragon
bash setup-mt7902-bluetooth.sh --rollback
sudo reboot
```

### Bluetooth File Locations

- Custom modules: `/lib/modules/$(uname -r)/updates/{btmtk.ko,btusb.ko}`
- Backup modules: `~/.config/mt7902_bluetooth_backup/`
- Build directory: `~/.local/src/mt7902_bluetooth/`
- Build log: `~/.local/src/mt7902_bluetooth/build.log`
- Autoload config: `/etc/modules-load.d/mt7902-bluetooth.conf`

### Important Notes

- **Kernel updates**: Bluetooth modules need to be recompiled after kernel updates (no DKMS for Bluetooth yet)
- **Recompile after kernel update**:

  ```bash
  cd ~/dotfiles/hosts/firedragon
  bash setup-mt7902-bluetooth.sh
  ```

- **WiFi first**: Install WiFi driver before Bluetooth if both are needed
- **Experimental**: Community-developed, may have stability issues

## Resources

- [MT7902 Driver Repository](https://github.com/OnlineLearningTutorials/mt7902_temp)
- [MT76 Driver Documentation](https://wireless.wiki.kernel.org/en/users/drivers/mt76)
- [Arch Linux WiFi Guide](https://wiki.archlinux.org/title/Network_configuration/Wireless)
- [DKMS Documentation](https://wiki.archlinux.org/title/Dynamic_Kernel_Module_Support)

## Support & Community

- **Arch Linux Forums**: <https://bbs.archlinux.org/>
- **Driver Issues**: <https://github.com/OnlineLearningTutorials/mt7902_temp/issues>
- **General WiFi Help**: r/archlinux on Reddit

---

**Last Updated**: October 31, 2024
**Status**: Community driver (experimental)
**Tested on**: Asus VivoBook with AMD, Arch Linux, Kernel 6.x
