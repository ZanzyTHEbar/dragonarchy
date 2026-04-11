# Proxmox VM Template Strategy

## Purpose

This document defines the VM-template strategy for disposable branch-shift and chezmoi cutover validation on Proxmox.

The goal is not to replace the current QEMU CI smoke lane.

The goal is to add a stronger desktop-capable validation substrate before any real-host validation or bringup is considered for hosts such as `goldendragon` or `firedragon`.

## Decision

Use a three-layer model:

1. gold cloud-base templates created directly from official cloud images
2. Packer-built validation templates cloned from those gold bases
3. disposable validation VMs cloned from the validation templates

## Why this is the best fit

### Official cloud images for the gold layer

Use official cloud images for Debian and Arch because they are:

- repeatable
- cloud-init native
- fast to import into Proxmox
- easier to refresh than ISO installs

For this repo, the gold layer should be:

- `debian-14-cloud-base`
- `arch-cloud-base`

Do not use CachyOS as the gold template.

The repo is Arch-first in daily use, but CachyOS is the wrong substrate for repeatable disposable validation because the important requirement here is cloud-init-backed reproducibility, not workstation flavor.

If CachyOS behavior matters, test it later as a follow-on disposable VM lane after the Arch cloud-image lane is stable.

### Packer for the validation layer

Use `proxmox-clone` for the validation-template layer because it is good at:

- cloning a prepared cloud-init-ready template
- provisioning repo-validation tooling
- freezing a reusable validation template artifact

For this repo, the validation layer should add:

- `git`
- `stow`
- `python`
- `chezmoi`
- `qemu-guest-agent`

That makes the validation template the reproducible handoff between infrastructure and repo validation.

For graphical Arch validation, use a separate desktop-class validation template rather than mutating the headless Arch lane.

That graphical template should add:

- Hyprland session packages
- Wayland portal packages
- a virtual VGA adapter suitable for a desktop console
- guest helpers such as `spice-vdagent`
- VM-safe rendering defaults for nested graphical validation

### Disposable clones for the execution layer

The disposable VM is where the actual scenario runs:

1. clone the validation template
2. boot with cloud-init
3. move repo state from `main` to `feat/ansible-chezmoi-foundation`
4. hard-reset the worktree after checkout
5. run the cutover workflow

This keeps the validation template immutable and the risky stateful work disposable.

## Boundary with existing control planes

### Packer owns

- template baking
- validation-template prerequisites
- guest baseline for disposable VM creation

### Ansible owns

- converging the real or disposable host after boot
- system-state ownership under `infra/ansible`

### Chezmoi owns

- generated user-state rendering
- cutover orchestration under `infra/chezmoi`

## Builder choice

### `proxmox-clone`

Use `proxmox-clone` for:

- Debian validation template builds
- Arch validation template builds
- any workflow that starts from a prepared cloud-init gold template

### `proxmox-iso`

Do not use `proxmox-iso` for the normal Debian or Arch gold-template path.

Only use it when:

- a distro does not publish a usable cloud image
- a test requires installer-time behavior that a cloud image cannot represent

## Dirty repo mitigation

The disposable VM workflow must treat `main -> feature` branch shifts as a two-step operation:

```bash
git fetch origin feat/ansible-chezmoi-foundation
git checkout -B feat/ansible-chezmoi-foundation FETCH_HEAD
git reset --hard FETCH_HEAD
```

The hard reset is not a repo-design replacement for `install.sh --fresh`.

It is a disposable-VM worktree normalization step after the branch shift.

## Recommended lanes

### Debian 14 lane

Use first for:

- branch-shift validation
- Stow baseline creation from `main`
- first chezmoi cutover execution path

### Arch lane

Use second for:

- Hyprland/session-adjacent confidence
- Arch-specific package/runtime validation
- user-session behavior before touching live Arch hosts

### Arch graphical lane

Use after the headless Arch disposable lane is already stable.

Its job is narrower:

- prove a desktop-capable Arch validation substrate exists
- give Hyprland and session tooling a real graphical VM surface
- keep that proof isolated from the simpler cloud-image headless cutover lane

## Acceptance rule

Do not consider any real-host validation or bringup until all of the following are true:

1. Debian disposable cutover remains clean and repeatable
2. Arch disposable validation proves the session path is stable enough for host-local behavior checks
3. Arch graphical validation proves Hyprland can hold a real tty-backed graphical session with sane compositor state

After those are true, the next step is still not a real host.

The next step is the first safe non-production execute cutover with an explicit rollback plan.
