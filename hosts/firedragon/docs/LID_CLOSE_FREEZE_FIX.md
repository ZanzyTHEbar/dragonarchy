# Lid Close Freeze Fix for FireDragon

## 🎯 Problem

When closing the laptop lid on FireDragon, the system suspends but **freezes on resume** when the lid is reopened. This requires a hard reboot to recover. However:

- ✅ Locking works fine (hyprlock)
- ✅ Manual suspend works fine (`systemctl suspend`)
- ❌ **Lid close suspend causes freeze on resume**

## 🔍 Root Cause

The issue was caused by a **missing systemd service**: `amdgpu-console-restore.service`

While the documentation (`SUSPEND_RESUME_COMPLETE_FIX.md`) mentioned this service as critical for fixing TTY framebuffer corruption after suspend/resume, the service file was **not present** in the dotfiles and the setup script was not installing it.

### The Missing Piece

The `amdgpu-console-restore.service` performs a critical VT (virtual terminal) switch after resume:

```bash
# Switch away and back to the active VT to re-init the framebuffer.
# (Don't hardcode tty7 — Wayland sessions are often on tty1.)
cur="$(fgconsole)"
tgt="1"; [ "$cur" = "1" ] && tgt="2"
chvt "$tgt"
sleep 0.2
chvt "$cur"
```

This reinitializes the framebuffer driver, preventing the freeze/corruption that occurs when the lid closes.

### Why It Matters for Lid Close Specifically

Lid-triggered suspend behaves differently from manual suspend:

- Manual suspend: System has time to properly prepare display/GPU
- Lid close: Rapid suspend can leave GPU in inconsistent state
- Without console restore: Framebuffer doesn't recover properly → freeze

## 🛠️ Solution

The fix involves three new/updated components:

### 1. **amdgpu-console-restore.service** (NEWLY CREATED)

```ini
[Unit]
Description=AMD GPU Console/TTY Framebuffer Restore After Resume
After=amdgpu-resume.service suspend.target hibernate.target
StopWhenUnneeded=yes

[Service]
Type=oneshot
User=root
ExecStart=/usr/bin/sleep 0.5
ExecStart=/bin/sh -c 'command -v chvt >/dev/null 2>&1 || exit 0; cur="$(fgconsole 2>/dev/null || echo 1)"; case "$cur" in (""|*[!0-9]*) cur=1;; esac; tgt=1; [ "$cur" = "1" ] && tgt=2; chvt "$tgt" 2>/dev/null || true; sleep 0.2; chvt "$cur" 2>/dev/null || true'
ExecStart=/bin/sh -c 'echo "Console framebuffer restored at $(date -Is)" > /tmp/amdgpu-console.log'

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
```

**Key points:**
- Runs **after** `amdgpu-resume.service` completes
- Forces VT switch to reinitialize framebuffer
- Logs success for debugging

### 2. **Updated setup.sh** (MODIFIED)

Added installation and enablement of the console restore service:

```bash
sudo cp -f "$HOME/dotfiles/hosts/firedragon/etc/systemd/system/amdgpu-console-restore.service" /etc/systemd/system/
sudo systemctl enable amdgpu-console-restore.service
```

### 2b. **Limine Drop-in for Persistent Kernel Parameters** (NEW)

To prevent `limine-update` from wiping custom parameters, a drop-in is now installed automatically:

```bash
/etc/limine-entry-tool.d/10-amdgpu.conf
KERNEL_CMDLINE[default]+=" amdgpu.modeset=1"
```

The fix scripts call `limine-update` or `limine-mkinitcpio` so the regenerated `limine.conf` picks up the drop-in without manual edits.

### 3. **Automated Fix Script** (NEW)

Created `fix-lid-close-freeze.sh` to:
- Install all three AMD GPU services (suspend, resume, console-restore)
- Verify logind configuration
- Check AMD GPU modprobe settings
- Rebuild initramfs if needed
- Verify TLP doesn't interfere
- Provide clear next steps

## Status

This document is retained as historical context.

The legacy `fix-lid-close-freeze.sh` helper is retired.

Current ownership is split across:

- `infra/ansible/roles/amd_gpu`
- `infra/ansible/roles/asus_laptop`
- `infra/ansible/roles/tlp`
- `infra/ansible/roles/hibernation`

## Current Convergence Path

Converge the canonical owners:

```bash
ansible-playbook -i ~/dotfiles/infra/ansible/inventory/hosts.yml \
  ~/dotfiles/infra/ansible/playbooks/site.yml \
  --limit firedragon
```

The converged stack now owns:
1. ✅ Install all AMD GPU suspend/resume services
2. ✅ Verify systemd-logind configuration
3. ✅ Persist kernel module parameters
4. ✅ Verify hibernation and resume plumbing
5. ✅ Verify TLP configuration

**Then reboot if convergence changed boot or initramfs state.**

## ✅ Verification

After convergence, verify the stack:

```bash
~/dotfiles/tests/vm/proxmox-validation/firedragon-suspend-verify.sh
```

Expected output:

```
1️⃣  Checking kernel module parameters...
   ✅ amdgpu.modeset=1 loaded
   ✅ amdgpu.conf configured

2️⃣  Checking systemd services...
   ✅ amdgpu-suspend.service enabled
   ✅ amdgpu-resume.service enabled
   ✅ amdgpu-console-restore.service enabled  ← NEW!

3️⃣  Checking GPU power state...
   Current state: auto
   ✅ GPU power state is correct (auto)
```

## 🧪 Testing

Test in this order:

### 1. Lock Screen
```bash
loginctl lock-session
```
✅ Should lock and unlock properly

### 2. Manual Suspend
```bash
systemctl suspend
```
✅ Should suspend and resume without freeze

### 3. **Lid Close** (The Critical Test)
```bash
# Close laptop lid for 5+ seconds
# Open lid
```
✅ System should wake from suspend
✅ Screen should restore properly
✅ Should be locked (hyprlock)
✅ **No freeze!**

### 4. TTY Console
```bash
# Press Ctrl+Alt+F2 (switch to TTY)
# Should see login prompt (no freeze/blink)
# Press Ctrl+Alt+F7 (back to Hyprland)
```
✅ TTY should display properly

## 📊 Service Dependency Chain

```
Lid Closes
    ↓
logind triggers suspend
    ↓
amdgpu-suspend.service (runs BEFORE sleep.target)
    ↓
System Suspends
    ↓
Lid Opens
    ↓
System Resumes
    ↓
amdgpu-resume.service (runs AFTER suspend.target)
    ↓
amdgpu-console-restore.service (runs AFTER amdgpu-resume)  ← THE FIX!
    ↓
hypridle triggers DPMS restore
    ↓
✅ Screen fully restored, no freeze
```

## 🔧 For New Installations

The fix is now integrated into the setup process:

1. `amdgpu-console-restore.service` is now part of the dotfiles
2. `setup.sh` automatically installs and enables all three services
3. No manual intervention needed for new firedragon setups

## 📚 Related Files

- `/etc/systemd/system/amdgpu-suspend.service` - Pre-suspend GPU prep
- `/etc/systemd/system/amdgpu-resume.service` - Post-resume GPU restore
- `/etc/systemd/system/amdgpu-console-restore.service` - **Console framebuffer fix** (NEW!)
- `/etc/systemd/logind.conf.d/10-firedragon-lid.conf` - Lid behavior config
- `/etc/modprobe.d/amdgpu.conf` - Kernel module parameters
- `~/.config/hypr/hypridle.conf` - Idle/DPMS management

## 🚨 Troubleshooting

### Issue: Lid close still causes freeze

```bash
# Check if console-restore service is enabled
systemctl is-enabled amdgpu-console-restore.service

# Check if it ran after last resume
cat /tmp/amdgpu-console.log

# View service status
systemctl status amdgpu-console-restore.service
```

### Issue: Service is enabled but never runs

```bash
# Check service dependencies
systemctl list-dependencies amdgpu-console-restore.service

# View full systemd logs for resume
journalctl -b | grep -E "(Suspending|Resumed|amdgpu)" | tail -50
```

### Issue: TTY still shows artifacts after resume

The console restore service specifically addresses this. If TTY is still corrupted:

```bash
# Manually test VT switch
sudo sh -c 'cur="$(fgconsole)"; tgt="1"; [ "$cur" = "1" ] && tgt="2"; chvt "$tgt"; sleep 0.5; chvt "$cur"'

# If that fixes it, verify service is running:
systemctl status amdgpu-console-restore.service
```

## 📈 Success Criteria

After applying the fix, all these should work:

- ✅ Lock screen (`loginctl lock-session`)
- ✅ Manual suspend (`systemctl suspend`)
- ✅ **Lid close suspend** ← Fixed!
- ✅ Idle timeout suspend (hypridle)
- ✅ TTY console access (Ctrl+Alt+F2)
- ✅ Display restores after all suspend methods
- ✅ No screen freeze on resume
- ✅ No kernel panics or GPU errors

---

**Date:** 2025-11-10  
**Status:** Fixed - console-restore service added  
**Tested On:** FireDragon (AMD Ryzen 5 4600H + AMD Radeon RX 5500M)  
**Related:** See `SUSPEND_RESUME_COMPLETE_FIX.md` for comprehensive suspend/resume documentation

