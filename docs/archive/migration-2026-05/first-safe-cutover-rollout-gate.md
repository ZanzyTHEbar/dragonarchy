# First Safe Cutover Rollout Gate

## Purpose

This runbook defines the explicit go/no-go gate and rollback checklist for the first safe non-production Stow-to-chezmoi cutover.

It exists to keep every real host blocked until the parity catalog is complete, disposable-VM validation is complete, and the first execute target is a safe non-production machine.

Use this before:

- `docs/runbooks/first-host-chezmoi-cutover.md`

## Hard prerequisite

Before this runbook is even in scope, the parity program must be complete for the target host.

That means:

- `docs/architecture/host-bringup-parity-catalog.md` is complete for the target host and its required capabilities
- the target host has no remaining unresolved ownership seams that affect its bringup path
- the new owner path has already been proven on the disposable VM lanes

If those are not true, stop here.

Do not use this runbook to justify early real-host validation.

## Allowed first execute target

The first execute target must be:

- non-production
- disposable or easily rebuildable
- Arch-family if you want the strongest confidence before touching the live Hyprland fleet
- absent from the daily-driver set

The first execute target must not be:

- `goldendragon`
- `firedragon`

## Rollout gate

All of the following must be true before the first safe non-production execute cutover:

1. The parity catalog is complete for the exact host and no required bringup capability remains parity-incomplete.
2. Debian disposable validation is green.
3. Arch disposable validation is green.
4. Arch graphical disposable validation is green.
5. The exact branch intended for the cutover has passed the repo-local validation pass.
6. The target host can be restored quickly if the cutover regresses session behavior.
7. The operator has reviewed the dry-run output for the exact host and exact manifests that will be executed.

### Gate 1: Debian disposable proof

Required evidence:

- the Debian validation template boots
- `git`, `stow`, `chezmoi`, and required repo tooling are present
- the disposable Debian lane can shift from `main` to `feat/ansible-chezmoi-foundation`
- `git reset --hard FETCH_HEAD` normalizes the worktree
- `cutover-host.sh --execute` completes cleanly on the disposable Debian lane

This gate proves the basic branch-shift and cutover mechanics without Arch- or Hyprland-specific variables.

### Gate 2: Arch disposable proof

Required evidence:

- the Arch validation template boots cleanly with guest agent and SSH working
- the disposable Arch lane can repeat the branch-shift and cutover path
- minimal-image install assumptions are already corrected
- no new runtime-ownership or folded-Stow regressions appear

Package expectations: disposable lanes prove **repo-native** bootstrap tooling and workflow mechanics. **AUR/vendor** packages from `deps.manifest.toml` (`paru` / `script` managers) are a separate explicit gate—do not treat them as covered by the minimal Arch template alone.

This gate proves the same mechanics under the host family that matters for the live Hyprland fleet.

### Gate 3: Arch graphical proof

Required evidence:

- the graphical Arch disposable VM boots with a desktop-capable virtual VGA
- Hyprland can start on a real tty-backed graphical path
- the compositor stays up long enough to query with `hyprctl`
- at least one client window can map successfully

The current proof standard is:

- a live Hyprland process
- a valid Hyprland runtime socket
- a non-text VGA screenshot
- `hyprctl monitors` and `hyprctl clients` returning sane compositor state

This gate proves that the VM substrate is no longer only headless or package-level; it can host a real graphical Hyprland session.

### Gate 4: Branch-state proof

Required evidence:

- the working tree contains the intended cutover code and docs
- the operator has not mixed unrelated local changes into the execute target
- the exact repo-local validation pass for the branch is green:
  - shell syntax
  - lint checks on changed shell surfaces
  - Ansible syntax checks

### Gate 5: Safe target proof

Required evidence:

- the host is not relied on for daily work
- loss of the session for the duration of rollback is acceptable
- the current Stow-managed state is backed up or trivially recreatable
- the cutover backup path is writable:

```text
~/.local/state/dotfiles/backups/<timestamp>/chezmoi-cutover/<host>/
```

## Execute checklist

Run these in order on the safe target:

1. Converge Ansible system state first.
2. Build and verify generated chezmoi source for the exact host.
3. Review the Stow carve-out plan.
4. Run `cutover-host.sh` dry-run and confirm zero surprise blockers.
5. Record the exact backup root shown by the script.
6. Execute `cutover-host.sh --execute`.
7. Perform the post-cutover behavior checks immediately.

## Immediate rollback triggers

Rollback immediately if any of the following happen after execute mode:

- Hyprland fails to start
- the graphical session starts but core user-session tools fail in a way that blocks normal use
- migrated paths are missing or land outside the expected slice
- runtime/theme generators stop recreating their excluded files
- the host shows unexpected repo dirtiness caused by the cutover itself
- Stow ownership outside the intended migration slice appears to have changed

## Rollback checklist

Rollback is host-local and should be done before exploring secondary fixes.

1. Stop the session or switch to a recovery shell.
2. Capture the failing state:
   - `git status --short`
   - `chezmoi diff`
   - relevant session logs
3. Remove the migrated chezmoi-managed paths for the slice being rolled back.
4. Restore the backup contents from the backup root printed by `cutover-host.sh`.
5. Re-run the Stow package and host restow commands for the host if needed.
6. Confirm the host is back to the pre-cutover Stow-owned state.
7. Do not reattempt execute mode until the root cause is understood and the dry-run has been reviewed again.

## Minimum post-rollback checks

After rollback, confirm:

- migrated paths exist again under their pre-cutover layout
- Hyprland starts in the known-good pre-cutover state
- Waybar, swaync, swayosd, and clipse behave as they did before the execute attempt
- excluded runtime-owned files are again recreated normally

## Promotion rule

Only after the first safe non-production execute cutover is successful should the project consider whether any real-host validation is justified.

Even then:

- `goldendragon` and `firedragon` remain blocked until parity is complete and the safe-target result is reviewed
- the next host choice should be deliberate, not automatic
