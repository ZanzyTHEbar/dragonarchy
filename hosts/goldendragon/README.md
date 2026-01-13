# GoldenDragon (Lenovo ThinkPad P16s Gen 4 Intel - Type 21QV/21QW)

Host-specific configuration for a **professional Lenovo ThinkPad P16s Gen 4 (Intel)** mobile workstation.

This host aims to be **boring and reliable**: good power management, sane lid/sleep behavior, clean firmware updates, and GPU-aware setup (Intel-only or Intel+NVIDIA).

## Hardware Notes

- **Model**: ThinkPad P16s Gen 4 (Intel)
- **Machine types**: **21QV / 21QW** (treated the same for configuration purposes)
- **GPU**: Either Intel iGPU-only **or** hybrid Intel iGPU + NVIDIA RTX PRO (auto-detected)

## What This Host Configures

- **Power management**: TLP (battery thresholds, runtime PM, USB autosuspend hygiene)
- **Thermals**: `thermald` + `lm_sensors` support (user runs `sensors-detect`)
- **Sleep / lid**: `systemd-logind` lid policy + `systemd` sleep mode toggles
- **Firmware**: `fwupd` tooling for BIOS/UEFI/device firmware updates
- **Graphics**:
  - Intel-only systems: Intel media/Vulkan tooling
  - NVIDIA systems: NVIDIA drivers + required kernel parameters for Wayland/Hyprland
- **Quality-of-life**:
  - `battery-status` helper
  - user `battery-monitor.timer` if the `hardware` package is installed
- **Existing host tweaks retained**:
  - `v4l2loopback` module config (virtual camera)
  - `systemd-resolved` DNS drop-in (if you use it)
  - **Fingerprint auth (if hardware is detected)**: installs/enables `fprintd` and wires PAM for sudo/polkit/SDDM with password fallback

## Install / Run

From the dotfiles root:

```bash
cd ~/dotfiles
./install.sh --host goldendragon
```

Or run only the host setup:

```bash
cd ~/dotfiles/hosts/goldendragon
bash setup.sh
```

## Fingerprint Setup / Verification

This host can enable fingerprint authentication via **fprintd** (when a sensor is detected).

- **What gets enabled**:
  - `fprintd.service`
  - PAM rules for `/etc/pam.d/sudo`, `/etc/pam.d/polkit-1`, `/etc/pam.d/system-local-login`, `/etc/pam.d/sddm`
  - A host-scoped `/etc/pam.d/hyprlock` that includes `system-local-login` (so Hyprlock can use fingerprint too)
  - Password fallback remains enabled (fingerprint is added as `sufficient`, not `required`)

- **Verify wiring**:

```bash
cd ~/dotfiles/hosts/goldendragon
bash ./verify-fingerprint.sh
```

- **Enroll + test (interactive)**:

```bash
fprintd-enroll
fprintd-verify
sudo true
```

## Secure Boot (Limine + sbctl)

Goldendragon uses **Limine**. Secure Boot is managed with **sbctl**.

- **Helper script**: `hosts/goldendragon/setup-secure-boot.sh`
- **Docs**: `hosts/goldendragon/docs/SECURE_BOOT.md`

Quick start (after putting firmware into Secure Boot “Setup Mode”):

```bash
cd ~/dotfiles/hosts/goldendragon
sudo bash ./setup-secure-boot.sh --yes
```

## Post-Setup Checklist

1. **Reboot** (required for kernel/module + logind policy changes).
2. **Sensors**:

   ```bash
   sudo sensors-detect
   sensors
   ```

3. **Power management**:

   ```bash
   tlp-stat -s -p -b
   ```

4. **Sleep**:

   ```bash
   cat /sys/power/mem_sleep
   systemctl suspend
   ```

5. **GPU verification**:

   ```bash
   lspci -k | grep -A3 -i 'vga\|3d\|display\|nvidia'
   ```

6. **Firmware updates**:

   ```bash
   fwupdmgr get-devices
   fwupdmgr get-updates
   ```

## Optional: Hibernate

Hibernate requires swap + resume configuration. This host does not force-enable it by default; it can be added once you confirm your swap layout and desired behavior.

