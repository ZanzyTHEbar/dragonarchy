# Proxmox Validation Templates

This directory documents the Proxmox-backed disposable validation lane.

The implementation lives under:

- `infra/packer/`
- `docs/runbooks/proxmox-validation-template-workflow.md`

What it verifies:

- gold templates come from official Debian and Arch cloud images
- validation templates bake repo prerequisites with Packer
- Arch can also be baked into a desktop-class graphical validation template
- disposable VMs can reproduce the `main -> feat/ansible-chezmoi-foundation` branch shift
- disposable VMs normalize the worktree with `git reset --hard FETCH_HEAD`
- Debian and Arch lanes can exercise the chezmoi cutover workflow without touching live hosts
- the Arch graphical disposable lane can host a real tty-backed Hyprland session smoke

What it does not yet prove:

- live-host cutover on `goldendragon` or `firedragon`
- hardware-specific behavior that cannot be represented in a virtualized lane
- CachyOS-specific packaging or session quirks unless an explicit follow-on lane is added

What still remains between this lane and a live host:

- the explicit rollout gate and rollback checklist
- the first real execute cutover on a safe non-production target
