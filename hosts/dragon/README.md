## Dragon (AMD Workstation Desktop)

This host config targets **Dragon**, an all-AMD desktop with:

- **AIO cooler management** via `liquidctl` + `liquidctl-dragon.service`
- **Dynamic LED** control based on coolant temp via `dynamic_led.service`
- **Host DNS** via `hosts/dragon/etc/systemd/resolved.conf.d/dns.conf`
- **Sleep / power button policy** via `hosts/dragon/etc/systemd/*`
- **Audient iD22 PipeWire config** via `hosts/dragon/pipewire/` (installed by `scripts/utilities/audio-setup.sh`)

### What runs during install

`install.sh` will:

- Run `hosts/dragon/setup.sh`
- Stow `hosts/dragon/dotfiles/` into `$HOME` (if present)
- Apply “safe” hardware kernel params via `scripts/install/system-config.sh`

### Workstation GPU setup

See `hosts/dragon/docs/AMD_WORKSTATION.md` for:

- Vulkan / Mesa verification
- CoreCtrl setup notes
- Optional AMDGPU overdrive notes (opt-in)

