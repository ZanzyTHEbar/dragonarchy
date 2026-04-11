# First-Host Chezmoi Cutover Runbook

## Purpose

This runbook defines the canonical operator sequence for the first safe non-production Stow-to-chezmoi cutover.

It is intentionally concrete.

Use it when you want to move the current session-core, session-shell, and session-zsh slices from legacy Stow ownership to generated chezmoi ownership.

For disposable Proxmox machine preparation before this runbook, use:

- `docs/runbooks/proxmox-validation-template-workflow.md`

For the rollout gate, host block list, and rollback checklist that must be satisfied before using this runbook in execute mode, use:

- `docs/runbooks/first-safe-cutover-rollout-gate.md`

## Scope

This runbook currently applies to the first generated-source slice set:

- `session-core.manifest`
- `session-shell.manifest`
- `session-zsh.manifest`

That means the first migrated paths are:

- `~/.config/hypr`
- `~/.config/waybar`
- `~/.config/walker`
- `~/.config/elephant`
- `~/.config/autostart`
- `~/.config/clipse`
- `~/.config/swaync`
- `~/.config/swayosd`
- `~/.config/waybar-hosts/<host>`
- `~/.zshrc`
- `~/.zshenv`
- `~/.config/zsh`

Excluded runtime-owned exceptions remain outside generated source:

- `~/.config/swaync/style.css`
- `~/.config/clipse/theme.toml`

## Preconditions

Before starting, confirm all of the following:

1. The target host is one of the currently modeled inventory hosts.
2. The dotfiles repo is checked out on the target host at the intended branch and revision.
3. `chezmoi` is installed on the target host.
4. `stow` is installed on the target host.
5. The target host is expected to begin from a repo-managed Stow state for the migrated paths.
6. No legacy script will rewrite the migrated paths after apply.
7. The parity catalog in `docs/architecture/host-bringup-parity-catalog.md` is complete and parity-complete for the exact host and required capabilities.
8. The rollout gate in `docs/runbooks/first-safe-cutover-rollout-gate.md` is fully green for the exact branch and host you intend to cut over.
9. The target host is not `goldendragon` or `firedragon`.

Do not run the execute path if any of those are false.

## Recommended sequence

### 1. Converge system state first

Run the Ansible control plane before touching user-state ownership:

```bash
cd ~/dotfiles/infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --limit <host>
```

This ensures the target host already matches the current system-state owner model before user-state ownership shifts.

### 2. Build the generated chezmoi source

Run from the repo root on the target host:

```bash
cd ~/dotfiles
./infra/chezmoi/scripts/build-source.sh --host <host>
```

Expected result:

- generated source is rebuilt under `infra/chezmoi/generated/<host>/`

### 3. Verify the generated source

```bash
./infra/chezmoi/scripts/verify-generated-source.sh --host <host>
```

Expected result:

- all required generated paths exist
- excluded runtime-owned files stay absent

Do not continue if verification fails.

### 4. Review the Stow carve-out plan

```bash
./infra/chezmoi/scripts/plan-stow-cutover.sh --host <host>
```

Review the emitted output carefully.

You should see:

- the migrated `$HOME` path set
- the `hyprland` package carve-out
- the `zsh` package carve-out
- the `hosts/<host>/dotfiles` carve-out

Do not continue if the carve-out plan does not match the intended migration slice.

### 5. Run the cutover dry-run

```bash
./infra/chezmoi/scripts/cutover-host.sh --host <host>
```

Dry-run must complete without surprise blockers.

The script is expected to report:

- the generated-source build step
- the verifier step
- the Stow carve-out commands
- any repo-state blockers for migrated `$HOME` paths

If dry-run reports blocked paths, stop and resolve them first.

Typical causes:

- the path is not currently repo-managed
- local manual edits replaced a Stow-managed path
- a legacy setup script is still rewriting the target path

### 6. Execute the cutover

Only after dry-run output is correct:

```bash
./infra/chezmoi/scripts/cutover-host.sh --host <host> --execute
```

Execution behavior:

1. rebuild generated source
2. verify required and excluded paths
3. back up repo-managed migrated paths
4. remove migrated Stow-owned paths
5. restow package and host-dotfiles trees with manifest-derived `--ignore=...` carve-outs
6. run `chezmoi diff`
7. run `chezmoi apply`

Backups are written under:

```text
~/.local/state/dotfiles/backups/<timestamp>/chezmoi-cutover/<host>/
```

## Post-cutover checks

After execute mode, confirm the following:

```bash
test -d ~/.config/hypr
test -d ~/.config/waybar
test -d ~/.config/autostart
test -d ~/.config/swaync
test -e ~/.config/waybar-hosts/<host>
test -e ~/.zshrc
test -e ~/.zshenv
test -d ~/.config/zsh
test ! -e ~/.config/swaync/style.css
test ! -e ~/.config/clipse/theme.toml
```

Then perform real behavioral checks:

1. Start a fresh session.
2. Confirm Hyprland launches correctly.
3. Confirm Waybar, clipse, swaync, and swayosd still behave as expected.
4. Confirm runtime/theme generators still recreate their excluded files when appropriate.

If any of those checks fail, stop and follow the rollback checklist in:

- `docs/runbooks/first-safe-cutover-rollout-gate.md`

## Stop conditions

Stop immediately if:

- dry-run reports unexpected blocked paths
- generated-source verification fails
- carve-out commands target paths outside the intended migration slice
- a legacy setup path is still rewriting migrated files

## Notes

- This runbook assumes the current control-plane model where Ansible owns system state and chezmoi owns migrated `$HOME` state.
- `resolved` remains an inventory-owned rollout selector and is not part of this user-state cutover sequence.
- The first-host cutover should be treated as an operational milestone, not a casual local tweak.
- The first execute target must be a safe non-production machine even after the parity catalog is complete and the Debian, Arch, and graphical VM lanes are green.
