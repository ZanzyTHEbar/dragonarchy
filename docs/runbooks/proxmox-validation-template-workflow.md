# Proxmox Validation Template Workflow

## Purpose

This runbook defines the repeatable Proxmox workflow for disposable branch-shift and chezmoi cutover validation.

It complements:

- `docs/architecture/proxmox-vm-template-strategy.md`
- `docs/runbooks/first-host-chezmoi-cutover.md`
- `docs/runbooks/first-safe-cutover-rollout-gate.md`

## Target artifacts

Gold templates:

- `debian-14-cloud-base`
- `arch-cloud-base`

Validation templates:

- `dotfiles-debian-14-validation-template`
- `dotfiles-arch-validation-template`
- `dotfiles-arch-graphical-validation-template`

Disposable VMs:

- `dotfiles-cutover-debian-*`
- `dotfiles-cutover-arch-*`
- `dotfiles-graphical-arch-*`

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

Build the Arch graphical validation template:

```bash
./scripts/run-packer-build.sh \
  -only=arch-graphical-validation-template.proxmox-clone.arch_graphical_validation \
  -var-file=local.auto.pkrvars.hcl
```

The wrapper is required because the repo keeps the Packer HCL split across `sources/` and `builds/`, while `packer build .` only evaluates `.pkr.hcl` files in the current working directory.

Expected result:

- the builder clones the gold template
- installs validation prerequisites
- cleans cloud-init and machine identity state
- freezes a reusable validation template artifact

### Package tiers vs what a disposable VM proves

Canonical package definitions live in `scripts/install/deps.manifest.toml`. Resolution tiers:

| Tier | Managers | What disposable/bootstrap lanes should assume |
|------|-----------|-----------------------------------------------|
| **Repo-native** | `pacman` / `apt` | Safe to assert on a stock image with default repos (and optional Chaotic-AUR if your lane enables it). Ansible `packages` installs this tier via `export-package-plan.sh`. |
| **AUR** | `paru` | Requires an AUR helper and build deps; **not** implied by `ansible.builtin.package` / pacman-only convergence. Proves only if you explicitly run `install-deps.sh`, `paru`, or a dedicated gate. |
| **Script / vendor** | `script` | Downloaders or custom installers; treat as an explicit, separate proof. |

Minimal Arch bootstrap scripts under `infra/packer/scripts/bootstrap-arch*.sh` intentionally install **small repo-native sets** for SSH/agent/desktop smoke. They do **not** prove the full manifest (including AUR or `script` groups). Full composition is validated by `scripts/install/install-deps.sh` and inventory-driven `export-package-plan.sh` output.

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

Create a disposable Arch graphical VM:

```bash
./infra/packer/scripts/create-disposable-validation-vm.sh \
  --template dotfiles-arch-graphical-validation-template \
  --vm-id 9403 \
  --name dotfiles-graphical-arch-01 \
  --memory-mb 8192 \
  --cores 4 \
  --ssh-public-key-file ~/.ssh/id_ed25519.pub
```

The graphical Arch lane is the desktop-capable validation substrate used for the final virtualized gate before any safe non-production cutover is even considered.

It is expected to drive a real tty-backed graphical Hyprland smoke, not only package installation or SSH reachability checks.

Use linked clones only for short-lived experimentation.

Use full clones for any run whose artifacts or logs you want to preserve independently.

## Phase 4: Normalize repo state inside the disposable VM

The branch shift must be deterministic.

Inside the guest:

```bash
git clone --branch main https://github.com/ZanzyTHEbar/dragonarchy ~/dotfiles
cd ~/dotfiles
./install --host <hostname> --user-only
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

## Phase 6: Run host-specific parity probes when applicable

After the disposable host has been converged to the relevant target shape, run any host-specific read-only proof scripts needed for the parity surface you just changed.

Current example:

```bash
./tests/vm/proxmox-validation/firedragon-suspend-verify.sh
```

Use this after the firedragon laptop stack has been converged to verify:

- AMD GPU suspend/resume services
- ASUS sleep/logind policy
- hibernation and resume state
- Hypridle sleep-session policy
- ASUS profile state

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
| Arch disposable VM | Hyprland/session-adjacent validation is stable enough before any safe non-production cutover is considered | required before parity-complete Arch cutover work |
| Arch graphical validation template | template boots with a desktop-capable virtual VGA and graphical prerequisites | substrate for the real graphical Hyprland/session gate |
| Arch graphical disposable VM | Hyprland can start on a real tty-backed graphical path and expose sane compositor state | final virtualized gate before the first safe non-production cutover |

## Stop conditions

Stop immediately if:

- the gold template is not cloud-init-ready
- Packer build succeeds but the guest agent or SSH path is broken
- branch shift still leaves unexpected repo dirtiness after `git reset --hard FETCH_HEAD`
- cutover dry-run surfaces blockers that widen ownership boundaries
- the graphical disposable lane cannot hold a real Hyprland session long enough to query compositor state

## Promotion rule

Do not promote directly from the virtualized lanes to any real host.

The next step after Debian, Arch, and graphical validation is:

1. complete `docs/architecture/host-bringup-parity-catalog.md` for the exact target and required capabilities
2. pass the rollout gate in `docs/runbooks/first-safe-cutover-rollout-gate.md`
3. execute the first cutover only on a safe non-production target
