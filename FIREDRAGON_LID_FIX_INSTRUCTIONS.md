# FireDragon Lid Close Freeze - Deployment Instructions

## 📋 Summary

The lid close freeze issue on firedragon has been identified and fixed. The problem was a **missing systemd service** (`amdgpu-console-restore.service`) that reinitializes the GPU framebuffer after resume.

## 🔧 What Was Changed

### Files Created:
1. `hosts/firedragon/etc/systemd/system/amdgpu-console-restore.service` - The missing service
2. `hosts/firedragon/fix-lid-close-freeze.sh` - Automated deployment script
3. `hosts/firedragon/docs/LID_CLOSE_FREEZE_FIX.md` - Comprehensive documentation

### Files Modified:
1. `hosts/firedragon/setup.sh` - Now installs all three AMD GPU services
2. `hosts/firedragon/README.md` - Added troubleshooting section for lid close issue

## 🚀 Deployment Steps

### On Dragon Host (Current - Push Changes)

```bash
cd ~/dotfiles

# Review changes
git status
git diff

# Commit changes
git add hosts/firedragon/etc/systemd/system/amdgpu-console-restore.service
git add hosts/firedragon/fix-lid-close-freeze.sh
git add hosts/firedragon/setup.sh
git add hosts/firedragon/docs/LID_CLOSE_FREEZE_FIX.md
git add hosts/firedragon/README.md

git commit -m "fix(firedragon): add missing amdgpu-console-restore service for lid close freeze

- Create amdgpu-console-restore.service to reinitialize framebuffer after resume
- Update setup.sh to install and enable console-restore service
- Add fix-lid-close-freeze.sh automated deployment script
- Document lid close freeze issue and solution
- Update README with troubleshooting section

Fixes lid close suspend/resume freeze on firedragon host while keeping
manual suspend working correctly."

git push origin main
```

### On FireDragon Host (Apply Fix)

```bash
# Pull latest changes
cd ~/dotfiles
git pull

# Run automated fix script
./hosts/firedragon/fix-lid-close-freeze.sh

# The script will:
# 1. Install all AMD GPU services (suspend, resume, console-restore)
# 2. Verify logind configuration
# 3. Check AMD GPU kernel parameters
# 4. Rebuild initramfs if needed
# 5. Verify TLP configuration

# When prompted, reboot
# (Or manually: sudo reboot)
```

### After Reboot on FireDragon

```bash
# Verify the fix
~/dotfiles/hosts/firedragon/verify-suspend-fix.sh

# Expected output should show:
# ✅ amdgpu-console-restore.service enabled
```

### Test Lid Close

1. **Lock screen test**:
   ```bash
   loginctl lock-session
   # Should lock and unlock properly ✅
   ```

2. **Manual suspend test**:
   ```bash
   systemctl suspend
   # Press power button to wake
   # Should resume properly ✅
   ```

3. **Lid close test** (THE CRITICAL TEST):
   - Close laptop lid for 5+ seconds
   - Open lid
   - System should wake and display should restore ✅
   - Should be locked (hyprlock) ✅
   - **No freeze!** ✅

4. **TTY test**:
   - Press `Ctrl+Alt+F2` (switch to TTY)
   - Should see login prompt (no freeze/blink) ✅
   - Press `Ctrl+Alt+F7` (back to Hyprland)

## 🔍 Technical Details

### The Missing Service

The `amdgpu-console-restore.service` performs a VT (virtual terminal) switch after resume:

```bash
chvt 1    # Switch to tty1
chvt 7    # Switch back to tty7 (Hyprland)
```

This reinitializes the framebuffer driver, preventing GPU freeze after lid-triggered suspend.

### Why Lid Close Is Different

- **Manual suspend**: System has time to properly prepare display/GPU
- **Lid close**: Rapid suspend can leave GPU in inconsistent state
- **Without console restore**: Framebuffer doesn't recover → freeze

### Service Dependency Chain

```
Lid Closes
    ↓
amdgpu-suspend.service (prep GPU)
    ↓
System Suspends
    ↓
Lid Opens → System Resumes
    ↓
amdgpu-resume.service (restore GPU)
    ↓
amdgpu-console-restore.service (reinitialize framebuffer) ← THE FIX!
    ↓
✅ Screen restored, no freeze
```

## 📊 Verification Commands

```bash
# Check if all services are enabled
systemctl is-enabled amdgpu-suspend.service
systemctl is-enabled amdgpu-resume.service
systemctl is-enabled amdgpu-console-restore.service

# Check if console-restore ran after last resume
cat /tmp/amdgpu-console.log

# View systemd logs for suspend/resume
journalctl -b | grep -E "(Suspending|Resumed|amdgpu)" | tail -30
```

## 🚨 Troubleshooting

If lid close still causes freeze after applying the fix:

1. **Verify service is enabled**:
   ```bash
   systemctl is-enabled amdgpu-console-restore.service
   # Should output: enabled
   ```

2. **Check if service ran**:
   ```bash
   cat /tmp/amdgpu-console.log
   # Should show timestamp of last resume
   ```

3. **View service status**:
   ```bash
   systemctl status amdgpu-console-restore.service
   ```

4. **Manual VT switch test**:
   ```bash
   sudo chvt 1 && sleep 0.5 && sudo chvt 7
   # If this fixes a frozen screen, the service needs debugging
   ```

## 📚 Documentation

- **Quick Fix**: `hosts/firedragon/docs/LID_CLOSE_FREEZE_FIX.md`
- **General Suspend/Resume**: `hosts/firedragon/docs/SUSPEND_RESUME_COMPLETE_FIX.md`
- **Verification**: `hosts/firedragon/verify-suspend-fix.sh`
- **Troubleshooting**: `hosts/firedragon/README.md` (Troubleshooting section)

## ✅ Success Criteria

After deployment, all of these should work without issues:

- ✅ Lock screen (`loginctl lock-session`)
- ✅ Manual suspend (`systemctl suspend`)
- ✅ **Lid close suspend** ← Main fix target
- ✅ Idle timeout suspend (hypridle)
- ✅ TTY console access (Ctrl+Alt+F2)
- ✅ Display restores after all suspend methods
- ✅ No screen freeze on resume

---

**Date**: 2025-11-10  
**Issue**: Lid close causes freeze on resume  
**Solution**: Added missing amdgpu-console-restore.service  
**Status**: Ready for deployment to firedragon

