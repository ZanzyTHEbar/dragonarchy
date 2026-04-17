# Complete Suspend/Resume Fix for Firedragon (AMD GPU + TTY)

## 🎯 Problem Summary

After initial testing, we found:

- ✅ **Locking works fine** - hyprlock properly locks/unlocks
- ❌ **Sleep/idle causes screen freeze** - System suspends but screen doesn't restore on resume
- ❌ **TTY shows blinking cursor, cannot login** - Console framebuffer not restoring after suspend

## 🔍 Root Causes Identified

1. **Initramfs not rebuilt** - `/etc/modprobe.d/amdgpu.conf` parameters weren't loaded into kernel
2. **Service dependencies incorrect** - Systemd services never triggered on suspend/resume
3. **TTY console framebuffer corruption** - AMD GPU framebuffer not restoring after suspend
4. **DPMS restore timing** - Display power management not synchronized with GPU resume

## 🛠️ Complete Solution

The fix addresses **all three layers** of the problem:

### **Layer 1: Kernel Module Parameters**
```bash
/etc/modprobe.d/amdgpu.conf
```
- `gpu_reset=0` - Prevents GPU reset hangs on suspend
- `runpm=1` - Enables runtime power management
- `modeset=1` - Enables early kernel mode setting for TTY
- `/etc/limine-entry-tool.d/10-amdgpu.conf` ensures `amdgpu.modeset=1` is re-applied whenever `limine-update` regenerates `limine.conf`

### **Layer 2: Systemd Suspend/Resume Hooks**
```bash
/etc/systemd/system/amdgpu-suspend.service    # Pre-suspend GPU prep
/etc/systemd/system/amdgpu-resume.service     # Post-resume GPU restore
/etc/systemd/system/amdgpu-console-restore.service  # TTY framebuffer fix
```

### **Layer 3: Hypridle DPMS Management**
```ini
~/.config/hypr/hypridle.conf
```
- `after_sleep_cmd = hyprctl dispatch dpms on`
- `before_sleep_cmd = loginctl lock-session`

## Status

This document is retained as historical context.

The legacy `fix-lid-close-freeze.sh` mutator is retired.

## Current Convergence Path

Converge the canonical owners:

```bash
ansible-playbook -i ~/dotfiles/infra/ansible/inventory/hosts.yml \
  ~/dotfiles/infra/ansible/playbooks/site.yml \
  --limit firedragon
```

**The converged role set will ensure:**
1. Configure AMD GPU kernel module parameters
2. **Rebuild initramfs** when needed ⚠️ **CRITICAL STEP!**
3. Install 3 systemd services for suspend/resume/TTY
4. Preserve the Hypridle sleep policy under the chezmoi-owned session config
5. Expose a read-only verification probe

**IMPORTANT:** 
- ⚠️ **REBOOT REQUIRED** - Changes will NOT work until reboot
- ⚠️ Do NOT restart services manually
- ⚠️ Do NOT log out before reboot

## ✅ Verification

After convergence, run the verification probe:

```bash
~/dotfiles/tests/vm/proxmox-validation/firedragon-suspend-verify.sh
```

**Expected output:**
```
1️⃣  Checking kernel module parameters...
   ✅ amdgpu.modeset=1 loaded
   ✅ amdgpu.conf configured

2️⃣  Checking systemd services...
   ✅ amdgpu-suspend.service enabled
   ✅ amdgpu-resume.service enabled
   ✅ amdgpu-console-restore.service enabled

3️⃣  Checking GPU power state...
   Current state: auto
   ✅ GPU power state is correct (auto)
```

## 🧪 Testing Procedure

Test in this order:

### **1. Test Lock Screen**
```bash
loginctl lock-session
```
✅ Should lock screen immediately
✅ Should unlock with password
✅ Display should restore properly

### **2. Test Manual Suspend**
```bash
systemctl suspend
```
✅ System should suspend
✅ Press power button to wake
✅ Screen should restore without freeze
✅ Should prompt for password (auto-locked)

### **3. Test Lid Close**
```bash
# Close laptop lid for 5+ seconds
# Open lid
```
✅ System should wake from suspend
✅ Screen should restore
✅ Should be locked

### **4. Test TTY Console**
```bash
# Press Ctrl+Alt+F2 (switch to TTY)
# Should see login prompt (no freeze/blink)
# Press Ctrl+Alt+F7 (back to Hyprland)
```
✅ TTY should display properly
✅ Login prompt should be stable
✅ Can switch back to Hyprland

## 📊 Monitoring & Logs

### **Check Service Status**
```bash
systemctl status amdgpu-suspend.service amdgpu-resume.service
```

### **View Resume Logs**
```bash
cat /tmp/amdgpu-resume.log
cat /tmp/amdgpu-console.log
```

### **Check Suspend/Resume Events**
```bash
journalctl -b | grep -E "(Suspending|Resumed|amdgpu)" | tail -30
```

### **GPU Power State**
```bash
cat /sys/class/drm/card*/device/power_dpm_force_performance_level
```
Should output: `auto`

### **Kernel Parameters**
```bash
cat /proc/cmdline | grep amdgpu
```
Should include: `amdgpu.modeset=1`

## 🚨 Troubleshooting

### **Issue: Services enabled but never run**
```bash
# Check if initramfs was rebuilt
ls -la /boot/initramfs* | head -5

# Rebuild manually if needed
sudo dracut --force --verbose    # CachyOS/Fedora
# OR
sudo mkinitcpio -P               # Arch-based
```

### **Issue: TTY still shows blinking cursor**
```bash
# Verify console restore service is active
systemctl status amdgpu-console-restore.service

# Check if it ran after last resume
cat /tmp/amdgpu-console.log
```

### **Issue: Screen freeze after idle timeout**
```bash
# Verify hypridle is running with correct config
ps aux | grep hypridle

# Check hypridle config
cat ~/.config/hypr/hypridle.conf | grep -E "(after_sleep|dpms)"
```

### **Issue: Suspend works but resume hangs**
```bash
# Check TLP isn't interfering
sudo systemctl status tlp
cat /etc/tlp.d/01-firedragon.conf | grep RUNTIME_PM

# Should be:
# RUNTIME_PM_ON_AC=auto
# RUNTIME_PM_ON_BAT=auto
```

## 📚 Technical Details

### **Why Initramfs Rebuild is Critical**

The kernel loads `amdgpu` module **very early** in boot process, before `/etc/modprobe.d/` is available. The initramfs (initial RAM filesystem) contains early boot files, including module parameters.

When you edit `/etc/modprobe.d/amdgpu.conf`, you **must** rebuild initramfs to include these changes:

```bash
# CachyOS/Fedora (dracut)
sudo dracut --force --verbose

# Arch-based (mkinitcpio)
sudo mkinitcpio -P
```

Without this step, the kernel uses **default** amdgpu parameters, which cause suspend/resume issues.

### **Service Dependency Chain**

```
Suspend Triggered
    ↓
amdgpu-suspend.service (runs BEFORE sleep.target)
    ↓
System Suspends
    ↓
System Resumes
    ↓
amdgpu-resume.service (runs AFTER suspend.target)
    ↓
amdgpu-console-restore.service (runs AFTER amdgpu-resume)
    ↓
hypridle triggers DPMS restore
```

### **TTY Framebuffer Restoration**

The TTY console fix works by forcing a VT (virtual terminal) switch:
```bash
# Switch away and back to the active VT to re-init the framebuffer.
# (Don't hardcode tty7 — Wayland sessions are often on tty1.)
cur="$(fgconsole)"
tgt="1"; [ "$cur" = "1" ] && tgt="2"
chvt "$tgt"
sleep 0.2
chvt "$cur"
```

This reinitializes the framebuffer driver, fixing the blank/corrupted display.

## 🔗 Related Files

- `/etc/modprobe.d/amdgpu.conf` - Kernel module parameters
- `/etc/systemd/system/amdgpu-*.service` - Suspend/resume hooks
- `~/.config/hypr/hypridle.conf` - Idle/DPMS management
- `/etc/tlp.d/01-firedragon.conf` - Power management (don't interfere with GPU)

## 📈 Success Criteria

All these should work without issues:

- ✅ Lock screen (`loginctl lock-session`)
- ✅ Manual suspend (`systemctl suspend`)
- ✅ Lid close suspend
- ✅ Idle timeout suspend (hypridle)
- ✅ TTY console access (Ctrl+Alt+F2)
- ✅ Display restores after all suspend methods
- ✅ No screen freeze on resume
- ✅ No kernel panics or GPU errors in logs

---

**Last Updated:** 2025-11-08  
**Status:** Complete fix for all reported issues  
**Tested On:** Firedragon (AMD Ryzen 5 4600H + AMD Radeon RX 5500M)



