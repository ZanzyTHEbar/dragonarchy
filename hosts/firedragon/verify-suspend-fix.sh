#!/bin/bash
# Verify firedragon sleep stack: suspend/resume + hibernate readiness

GIB=$((1024 * 1024 * 1024))

echo "═══════════════════════════════════════════════════════════════"
echo "  🔍 Firedragon Sleep/Hibernate Verification"
echo "═══════════════════════════════════════════════════════════════"
echo

echo "1️⃣  Checking kernel cmdline parameters..."
if grep -q "amdgpu.modeset=1" /proc/cmdline; then
    echo "   ✅ amdgpu.modeset=1 present"
else
    echo "   ❌ amdgpu.modeset=1 missing"
fi

if grep -q "resume=" /proc/cmdline; then
    echo "   ✅ resume= present"
else
    echo "   ❌ resume= missing (hibernate will NOT resume)"
fi

if grep -q "resume_offset=" /proc/cmdline; then
    echo "   ✅ resume_offset= present (swapfile resume)"
else
    echo "   ℹ️  resume_offset= not present (OK if you use a swap partition)"
fi

echo
echo "2️⃣  Checking kernel module configuration..."
if grep -q "options amdgpu gpu_reset=0" /etc/modprobe.d/amdgpu.conf 2>/dev/null; then
    echo "   ✅ /etc/modprobe.d/amdgpu.conf configured"
else
    echo "   ❌ /etc/modprobe.d/amdgpu.conf missing or incomplete"
fi

echo
echo "3️⃣  Checking systemd services..."
systemctl is-enabled amdgpu-suspend.service >/dev/null 2>&1 && echo "   ✅ amdgpu-suspend.service enabled" || echo "   ❌ amdgpu-suspend.service NOT enabled"
systemctl is-enabled amdgpu-resume.service >/dev/null 2>&1 && echo "   ✅ amdgpu-resume.service enabled" || echo "   ❌ amdgpu-resume.service NOT enabled"
systemctl is-enabled amdgpu-console-restore.service >/dev/null 2>&1 && echo "   ✅ amdgpu-console-restore.service enabled" || echo "   ❌ amdgpu-console-restore.service NOT enabled"

echo
echo "4️⃣  Checking GPU power state..."
GPU_STATE=$(cat /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null | head -n1)
echo "   Current state: ${GPU_STATE:-unknown}"
if [ "${GPU_STATE:-}" = "auto" ]; then
    echo "   ✅ GPU power state is correct (auto)"
else
    echo "   ⚠️  GPU power state is not 'auto' (may be OK depending on workload)"
fi

echo
echo "5️⃣  Checking hibernation prerequisites..."
MEM_KB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
MEM_BYTES=$((MEM_KB * 1024))
MEM_GIB=$(((MEM_BYTES + GIB - 1) / GIB))
echo "   RAM: ~${MEM_GIB} GiB"

DISK_SWAP_BYTES=$(swapon --show --noheadings --bytes --output=NAME,SIZE 2>/dev/null | awk '$1 !~ /^\/dev\/zram/ {sum+=$2} END{print sum+0}')
DISK_SWAP_GIB=$(((DISK_SWAP_BYTES + GIB - 1) / GIB))
echo "   Disk swap (active, excludes zram): ~${DISK_SWAP_GIB} GiB"
if [ "$DISK_SWAP_BYTES" -ge "$MEM_BYTES" ]; then
    echo "   ✅ Disk swap is large enough for hibernate"
else
    echo "   ❌ Disk swap is too small for hibernate"
fi

if [ -r /sys/power/state ] && grep -qw "disk" /sys/power/state; then
    echo "   ✅ Kernel reports hibernate support (disk) in /sys/power/state"
else
    echo "   ❌ Kernel does not report 'disk' in /sys/power/state"
fi

if [ -f /etc/mkinitcpio.conf ]; then
    if grep -Eq '^HOOKS=.*(sd-resume|resume)' /etc/mkinitcpio.conf; then
        echo "   ✅ mkinitcpio HOOKS include resume support"
    else
        echo "   ⚠️  mkinitcpio HOOKS missing resume hook"
    fi
fi

if command -v loginctl >/dev/null 2>&1; then
    CAN_HIBERNATE=$(loginctl show-seat seat0 -p CanHibernate --value 2>/dev/null || true)
    if [ -n "${CAN_HIBERNATE:-}" ]; then
        echo "   login1 CanHibernate: ${CAN_HIBERNATE}"
    fi
fi

echo
echo "6️⃣  Checking recent suspend/resume logs..."
if [ -f /tmp/amdgpu-resume.log ]; then
    echo "   Last resume event:"
    tail -3 /tmp/amdgpu-resume.log | sed 's/^/   /'
else
    echo "   ℹ️  No resume logs yet (haven't suspended since last boot)"
fi

if [ -f /tmp/amdgpu-console.log ]; then
    echo "   Last console restore event:"
    tail -3 /tmp/amdgpu-console.log | sed 's/^/   /'
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  💡 Test Procedure:"
echo "═══════════════════════════════════════════════════════════════"
echo "  1. Lock: loginctl lock-session"
echo "  2. Suspend: systemctl suspend"
echo "  3. Lid close: close laptop lid for 5+ seconds, then open"
echo "  4. Hibernate: systemctl hibernate"
echo "  5. TTY: Ctrl+Alt+F2, then Ctrl+Alt+F1 (or back to your active VT)"
echo "═══════════════════════════════════════════════════════════════"
