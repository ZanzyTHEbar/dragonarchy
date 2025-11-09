#!/bin/bash
# Verify suspend/resume fix is working

echo "═══════════════════════════════════════════════════════════════"
echo "  🔍 Suspend/Resume Fix Verification"
echo "═══════════════════════════════════════════════════════════════"
echo

echo "1️⃣  Checking kernel module parameters..."
if grep -q "amdgpu.modeset=1" /proc/cmdline; then
    echo "   ✅ amdgpu.modeset=1 loaded"
else
    echo "   ❌ amdgpu.modeset=1 NOT loaded (did you rebuild initramfs?)"
fi

if grep -q "options amdgpu gpu_reset=0" /etc/modprobe.d/amdgpu.conf; then
    echo "   ✅ amdgpu.conf configured"
else
    echo "   ❌ amdgpu.conf missing or incomplete"
fi

echo
echo "2️⃣  Checking systemd services..."
systemctl is-enabled amdgpu-suspend.service >/dev/null 2>&1 && echo "   ✅ amdgpu-suspend.service enabled" || echo "   ❌ amdgpu-suspend.service NOT enabled"
systemctl is-enabled amdgpu-resume.service >/dev/null 2>&1 && echo "   ✅ amdgpu-resume.service enabled" || echo "   ❌ amdgpu-resume.service NOT enabled"
systemctl is-enabled amdgpu-console-restore.service >/dev/null 2>&1 && echo "   ✅ amdgpu-console-restore.service enabled" || echo "   ❌ amdgpu-console-restore.service NOT enabled"

echo
echo "3️⃣  Checking GPU power state..."
GPU_STATE=$(cat /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null)
echo "   Current state: $GPU_STATE"
if [ "$GPU_STATE" = "auto" ]; then
    echo "   ✅ GPU power state is correct (auto)"
else
    echo "   ⚠️  GPU power state is not 'auto'"
fi

echo
echo "4️⃣  Checking recent suspend/resume logs..."
if [ -f /tmp/amdgpu-resume.log ]; then
    echo "   Last resume event:"
    tail -3 /tmp/amdgpu-resume.log | sed 's/^/   /'
else
    echo "   ⚠️  No resume logs yet (haven't suspended since reboot)"
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  💡 Test Procedure:"
echo "═══════════════════════════════════════════════════════════════"
echo "  1. Test lock: loginctl lock-session"
echo "  2. Test suspend: systemctl suspend"
echo "  3. Test lid close: close laptop lid"
echo "  4. Test TTY: Ctrl+Alt+F2, then Ctrl+Alt+F7"
echo "═══════════════════════════════════════════════════════════════"
