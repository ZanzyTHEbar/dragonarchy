## AMD Workstation (Dragon)

### Installed by this repo

On Arch-family installs, `scripts/install/install-deps.sh --host dragon` installs `platforms.arch.pacman.host_dragon_workstation` from `scripts/install/deps.manifest.toml`, including:

- **Vulkan/Mesa tooling**: `vulkan-tools`, `mesa-utils`, `vulkan-radeon`, `libva-mesa-driver`, `mesa-vdpau`
- **Monitoring/tuning**: `radeontop`, `lm_sensors`, `corectrl`
- **Microcode**: `amd-ucode`

`hosts/dragon/setup.sh` also attempts to install a small subset of these packages in a best-effort way (useful if you run it standalone).

### Verify GPU driver + Vulkan

Run:

```bash
lspci -k | grep -A3 -E "VGA|3D|Display"
glxinfo -B
vulkaninfo --summary
```

Expected:

- `Kernel driver in use: amdgpu`
- `vulkaninfo` shows an AMD ICD (RADV) and lists your GPU

### CoreCtrl

This host ships a polkit rule at:

- `/etc/polkit-1/rules.d/90-corectrl.rules`

It allows **wheel** users to use CoreCtrl’s helper without repeated prompts.

### Optional: AMDGPU “overdrive” / extra powerplay features

If you need advanced tuning features, there’s an **opt-in** example config:

- `hosts/dragon/etc/modprobe.d/amdgpu-dragon.conf`

It is **commented out** by default. Only enable settings you understand, and reboot after changes.

