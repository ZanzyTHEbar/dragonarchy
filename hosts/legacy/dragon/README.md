## Dragon (AMD Workstation Desktop)

This host config targets **Dragon**, an all-AMD desktop with:

- **AIO cooler management** via `liquidctl` + `liquidctl-dragon.service`
- **Dynamic LED** control based on coolant temp via `dynamic_led.service`
- **Host DNS** via Ansible `roles/resolved` role-local payloads
- **Sleep / power button policy** via `hosts/dragon/etc/systemd/*`
- **Audient iD22 PipeWire config** via `hosts/dragon/pipewire/` (installed by `scripts/utilities/audio-setup.sh`)

### Managed Bring-Up

Run Dragon through the Ansible control plane from the dotfiles root:

```bash
infra/ansible/run-playbook.sh infra/ansible/playbooks/site.yml --limit dragon
```

`hosts/dragon/setup.sh` and legacy install scripts remain reference material for
unported behavior; they are not the managed-host runtime writer for Ansible-owned
system state.

### Workstation GPU setup

See `hosts/dragon/docs/AMD_WORKSTATION.md` for:

- Vulkan / Mesa verification
- CoreCtrl setup notes
- Optional AMDGPU overdrive notes (opt-in)
