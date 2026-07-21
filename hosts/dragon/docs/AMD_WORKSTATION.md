## AMD Workstation (Dragon)

### Installed by this repo

On Arch-family installs, `scripts/install/install-deps.sh --host dragon` installs `platforms.arch.pacman.host_dragon_workstation` from `scripts/install/deps.manifest.toml`, including:

- **Vulkan/Mesa tooling**: `vulkan-tools`, `mesa-utils`, `vulkan-radeon`, `libva-mesa-driver`
- **Monitoring/tuning**: `radeontop`, `lm_sensors`, `corectrl`
- **Microcode**: `amd-ucode`

`hosts/dragon/setup.sh` is now legacy/reference for package installation; packages are owned by `deps.manifest.toml` and the Ansible `packages` role.

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
