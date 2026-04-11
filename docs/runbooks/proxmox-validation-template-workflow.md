# Proxmox Validation Template Workflow

## Purpose

This runbook defines the repeatable Proxmox workflow for disposable branch-shift and chezmoi cutover validation.

It complements:

- `docs/architecture/proxmox-vm-template-strategy.md`
- `docs/runbooks/first-host-chezmoi-cutover.md`

## Target artifacts

Gold templates:

- `debian-14-cloud-base`
- `arch-cloud-base`

Validation templates:

- `dotfiles-debian-14-validation-template`
- `dotfiles-arch-validation-template`

Disposable VMs:

- `dotfiles-cutover-debian-*`
- `dotfiles-cutover-arch-*`

## Phase 1: Create or refresh the gold template

Run on the Proxmox node:

```bash
./infra/packer/scripts/create-cloud-base-template.sh \
  --distro debian-14 \
  --vm-id 9100 \
  --name debian-14-cloud-base \
  --ssh-public-key-file ~/.ssh/id_ed25519.pub
```

For Arch:

```bash
./infra/packer/scripts/create-cloud-base-template.sh \
  --distro arch \
  --vm-id 9200 \
  --name arch-cloud-base \
  --ssh-public-key-file ~/.ssh/id_ed25519.pub
```

Keep the Arch validation lane aligned with the Arch gold-template firmware assumptions:

- BIOS: `seabios`
- machine type: `pc`

This phase should be rerun when the upstream cloud image is intentionally refreshed.

## Phase 2: Build the validation template with Packer

Prepare variables:

```bash
cd ~/dotfiles/infra/packer
cp local.auto.pkrvars.hcl.example local.auto.pkrvars.hcl
```

Build the Debian validation template:

```bash
./scripts/run-packer-build.sh \
  -only=debian-14-validation-template.proxmox-clone.debian_14_validation \
  -var-file=local.auto.pkrvars.hcl
```

Build the Arch validation template:

```bash
./scripts/run-packer-build.sh \
  -only=arch-validation-template.proxmox-clone.arch_validation \
  -var-file=local.auto.pkrvars.hcl
```

The wrapper is required because the repo keeps the Packer HCL split across `sources/` and `builds/`, while `packer build .` only evaluates `.pkr.hcl` files in the current working directory.

Expected result:

- the builder clones the gold template
- installs validation prerequisites
- cleans cloud-init and machine identity state
- freezes a reusable validation template artifact

## Phase 3: Clone a disposable VM

Create a disposable Debian VM:

```bash
./infra/packer/scripts/create-disposable-validation-vm.sh \
  --template dotfiles-debian-14-validation-template \
  --vm-id 9401 \
  --name dotfiles-cutover-debian-01 \
  --ssh-public-key-file ~/.ssh/id_ed25519.pub
```

Create a disposable Arch VM:

```bash
./infra/packer/scripts/create-disposable-validation-vm.sh \
  --template dotfiles-arch-validation-template \
  --vm-id 9402 \
  --name dotfiles-cutover-arch-01 \
  --ssh-public-key-file ~/.ssh/id_ed25519.pub
```

Use linked clones only for short-lived experimentation.

Use full clones for any run whose artifacts or logs you want to preserve independently.

## Phase 4: Normalize repo state inside the disposable VM

The branch shift must be deterministic.

Inside the guest:

```bash
git clone --branch main https://github.com/ZanzyTHEbar/dragonarchy ~/dotfiles
cd ~/dotfiles
./install.sh --dotfiles-only --no-packages --no-secrets
git fetch origin feat/ansible-chezmoi-foundation
git checkout -B feat/ansible-chezmoi-foundation FETCH_HEAD
git reset --hard FETCH_HEAD
```

The hard reset is required for the disposable validation workflow because the branch shift can otherwise leave a guest-local worktree anomaly where tracked files appear deleted.

## Phase 5: Run the cutover workflow

Inside the guest:

```bash
./infra/chezmoi/scripts/build-source.sh --host goldendragon
./infra/chezmoi/scripts/verify-generated-source.sh --host goldendragon
./infra/chezmoi/scripts/plan-stow-cutover.sh --host goldendragon
./infra/chezmoi/scripts/cutover-host.sh --host goldendragon
./infra/chezmoi/scripts/cutover-host.sh --host goldendragon --execute
```

For the full operator sequence and stop conditions, follow:

- `docs/runbooks/first-host-chezmoi-cutover.md`

## Decision table

| Need | Best choice | Why |
|---|---|---|
| Fast, repeatable Debian or Arch base | official cloud image + `create-cloud-base-template.sh` | cloud-init-native and simpler than ISO installers |
| Bake reusable validation tooling into a template | `packer build` with `proxmox-clone` | layers repo prerequisites without rebuilding the gold image |
| Run a disposable cutover experiment | `create-disposable-validation-vm.sh` | keeps the risky stateful work disposable |
| Test a distro with no usable cloud image | `proxmox-iso` | only use when cloud-image flow is unavailable |

## Acceptance matrix

| Lane | Must prove | Notes |
|---|---|---|
| Debian 14 validation template | template boots, cloud-init works, `git`/`python`/`chezmoi`/`stow` are present | primary branch-shift and cutover lane |
| Debian disposable VM | `main -> feature` checkout is normalized by hard reset and cutover sequence stays clean | first blocker-clearing lane |
| Arch validation template | template boots, guest agent works, Arch repo prerequisites are present | session-adjacent validation substrate |
| Arch disposable VM | Hyprland/session-adjacent validation is stable enough before live-host work | required before touching live Arch hosts |

## Stop conditions

Stop immediately if:

- the gold template is not cloud-init-ready
- Packer build succeeds but the guest agent or SSH path is broken
- branch shift still leaves unexpected repo dirtiness after `git reset --hard FETCH_HEAD`
- cutover dry-run surfaces blockers that widen ownership boundaries
