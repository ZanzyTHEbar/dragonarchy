# OpenCode Runtime Dragonarchy Runbook

## Scope

This runbook records the Dragonarchy issues found while applying the dotfiles to the OpenCode runtime container and the fixes that make the runtime use a dedicated host profile instead of reusing `microdragon`.

Runtime install command:

```bash
./install --host opencode-runtime
```

## Host Model

- `opencode-runtime` is a headless container host for the remote OpenCode workflow.
- It should use the full Dragonarchy machine bootstrap inside the OpenCode container.
- It should not inherit Raspberry Pi, NetBird routing peer, desktop, Hyprland, SDDM, laptop, or workstation assumptions.
- System state is owned by Dragonarchy Ansible after the container image provides the minimal bootstrap prerequisites required to run Ansible and chezmoi.

## Issues Found

### Missing `rsync`

- Symptom: `infra/chezmoi/bin/chezmoi-sync: line 110: rsync: command not found`.
- Cause: `chezmoi-sync` uses `rsync -a --delete` for directory sources, but the OpenCode image did not include `rsync`.
- Runtime mitigation used: add `rsync` to the OpenCode Docker image.
- Source requirement: any container image using Dragonarchy chezmoi sync must include `rsync`.

### Required SSH Runtime Files

- Symptom: `Error: Required source missing: packages/ssh/.ssh/config`.
- Symptom after first fix: `Error: Required source missing: packages/ssh/.ssh/known_hosts`.
- Cause: `infra/chezmoi/manifests/git-ssh.manifest` marked both files as required, but these files are runtime and host-specific.
- Runtime mitigation used during rollout: create empty files before running `./install`.
- Permanent fix: make `packages/ssh/.ssh/config` and `packages/ssh/.ssh/known_hosts` optional manifest entries so installs do not require runtime SSH state in source control.

### Required Kitty Runtime Theme File

- Symptom: `chezmoi: stat /home/coder/.local/share/chezmoi/dot_config/kitty/colors.conf: no such file or directory`.
- Cause: `packages/kitty/.config/kitty/colors.conf` is runtime theme state managed by the theme tooling, but it was copied into chezmoi source through the required Kitty directory.
- Runtime mitigation used: create `packages/kitty/.config/kitty/colors.conf` as a symlink to `themes/OneDark.conf` before running `./install`.
- Permanent fix: exclude `dot_config/kitty/colors.conf` from chezmoi sync so installs do not require or manage runtime dynamic theme files.

### Reusing `microdragon`

- Symptom: the OpenCode runtime reported successful install as host `microdragon`, even though it is not a Raspberry Pi or NetBird routing peer.
- Cause: `microdragon` existed as a Debian/server host and was the closest available inventory entry during rollout.
- Risk: future host-specific optional files or system-state assumptions could leak Raspberry Pi/NetBird behavior into the OpenCode container.
- Permanent fix: use the dedicated `opencode-runtime` host directory for this workflow.

## Deployment Notes

The OpenCode Coolify deployment should set:

```bash
LINUX_DOTFILES_URL=https://github.com/ZanzyTHEbar/dragonarchy.git
LINUX_DOTFILES_REF=feat/ansible-chezmoi-foundation
LINUX_DOTFILES_INSTALL_COMMAND=./install --host opencode-runtime
```

The previous compatibility command that created SSH placeholders and a Kitty `colors.conf` symlink can be removed after this commit is deployed.
