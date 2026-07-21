# Proxmox Validation Templates

`infra/packer/` owns the Proxmox template-baking layer for disposable validation machines.

It is intentionally separate from:

- `infra/ansible/`, which converges already-running hosts
- `infra/chezmoi/`, which stages and cuts over user-state ownership

## Design

The template pipeline has three layers:

1. gold cloud bases created from official cloud images
2. Packer-built validation templates cloned from those gold bases
3. disposable validation VMs cloned from the validation templates

This split is deliberate.

Official cloud images are the most repeatable substrate for Debian and Arch.

Packer then adds only the validation tooling that the repo needs:

- `git`
- `stow`
- `python`
- `chezmoi`
- `qemu-guest-agent`

That keeps the gold template small and makes the validation template the reproducible handoff point for cutover work.

The desktop-class Arch graphical lane adds only what the VM needs for Hyprland/session validation:

- Hyprland session packages
- Wayland portal packages
- virtual-GPU guest helpers such as `spice-vdagent`
- VM-safe graphical environment defaults for nested validation

## Layout

```text
infra/packer/
  README.md
  plugins.pkr.hcl
  variables.pkr.hcl
  sources/
  builds/
  scripts/
```

## Primary files

- `scripts/create-cloud-base-template.sh` creates the gold Debian or Arch base template directly on a Proxmox node from an official cloud image
- `sources/*.pkr.hcl` define the `proxmox-clone` builders for Debian and Arch validation templates
- `builds/*.pkr.hcl` define the provisioning and cleanup steps that freeze those templates
- `scripts/create-disposable-validation-vm.sh` clones a validation template into a disposable VM for branch-shift and cutover testing

## Usage

Run the build through the wrapper:

```bash
cd infra/packer
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

`run-packer-build.sh` stages a temporary flat workspace before invoking Packer.

That wrapper exists because the repo intentionally keeps Packer HCL split across `sources/` and `builds/`, while `packer build .` only evaluates `.pkr.hcl` files in the current working directory.

Create a disposable VM from a validation template:

```bash
./infra/packer/scripts/create-disposable-validation-vm.sh \
  --template dotfiles-debian-14-validation-template \
  --vm-id 9401 \
  --name dotfiles-cutover-debian-01 \
  --ssh-public-key-file ~/.ssh/id_ed25519.pub
```

## Operator docs

For the full workflow and acceptance matrix, use:

- `docs/architecture/proxmox-vm-template-strategy.md`
- `docs/runbooks/proxmox-validation-template-workflow.md`
- `tests/vm/proxmox-validation/README.md`
