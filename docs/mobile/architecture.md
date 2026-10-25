# Mobile Architecture — Dragonarchy

## Overview
Dragonarchy manages the Poco X3 Pro's Omalauncher experience from one repository.

**Current scope: Omalauncher only**, configured as one Dragonarchy host.
Omalauncher is the Android launcher and Wayland compositor; its optional Arch
Linux ARM guest runs through upstream PRoot. It does not run Hyprland.
DroidDesk, a separate Linux desktop and a fork are out of scope.

## Runtime Isolation
| Runtime | Package Mgr | Config Owner |
|---|---|---|
| Android/MIUI | Android PM | User/Android |
| Omalauncher Arch | pacman | Dragonarchy via chezmoi |

## Host Package
Single host-owned package: `hosts/poco-x3-pro/`
- Device descriptor: `device.yml`
- Omalauncher widgets: `dotfiles/.config/omalauncher/widgets/`
- Default theme: Gruvbox, selected by host-owned
  `~/.config/omalauncher/style/style.toml` (`version = 1`, `theme = "gruvbox"`).
- Theme palette: the existing shared Gruvbox `alacritty.toml`, mapped into
  `~/.config/omarchy/themes/gruvbox/alacritty.toml` by the manifest.
- Earlier Hyprland files and `theme.conf` remain inactive, excluded from manifests.
  They are not validated or deployment-ready.

## Configuration Flow
```
Dragonarchy repo → isolated manifest rendering → validation → review
```

Deployment and package bootstrap remain disabled. Local managed-file snapshot and
restore are implemented, but revision approval, runtime identity and post-apply
checks still need integration. Do not run an unscoped `chezmoi apply` against this
profile.

## Local checks

```bash
python3 tests/shell/mobile-safety-check.py
tests/shell/vendor/bin/bats tests/shell/chezmoi-sync.bats
bash scripts/mobile/validate.sh --render-only
OWL_JAR=/path/to/owl.jar bash scripts/mobile/validate.sh
```

Rendering uses a disposable source tree and never applies home files. The full
validator fails if the OWL checker is unavailable; rendering alone is not widget
validation. Shared development-tool configuration still needs a dependency audit.

## Upstream reference and ownership

Inspected Omalauncher v0.8.1 at commit
`06d4b484f268b30090da1cf235eae1c1fcd07762`:

- `LauncherData.kt`: widgets, user themes and style live outside the guest rootfs,
  bound at `~/.config/omalauncher/widgets`, `~/.config/omarchy/themes` and
  `~/.config/omalauncher/style` respectively.
- `theme/ThemeColors.kt` and `theme/ThemeStore.kt`: custom themes support
  `colors.toml` or legacy `alacritty.toml`. The earlier `theme.conf` is not valid.
- `theme/Style.kt` and `theme/StyleStore.kt`: style format version 1 supports a
  top-level `theme` name. The host owns the whole style file; omitted settings use
  upstream defaults. Local Style-menu edits will appear in the deployment diff
  and must be migrated into the host file if they should persist across deploys.
  Android home-role, permissions and private preferences remain manual.

Do not own widget directories wholesale: `.errors`, `.preview`, placement and
persisted state belong to the launcher. Do not directly manage terminal/editor
files that upstream regenerates from the active theme.

## OWL validation evidence

The pinned upstream `:owl:test` and `:owl:owlJar` tasks pass with JDK 17. All three
host widgets pass `owl.jar check`. Only `include(":app")` was excluded in the
temporary checkout to avoid requiring an Android SDK; OWL source/tests were
unchanged. CI now includes the same host-only build (not yet run remotely).

System Java is unchanged. Validation used Temurin 17.0.20.1+1 from the official
Adoptium release, checked against its API SHA-256:
`3808d1d15e3ec6bd5b84057fb5d84c33d8a1536a258146bcea2e603fc726e08e`.
On-device rendering, persistence and payment checks remain untested.

## Local file backup and restore

These helpers require Python 3.9+ and explicit absolute paths. Tests require
Python 3.11+ for TOML parsing. Use them inside the intended runtime, not an ADB
shell impersonating another Android application's UID.

Create a private backup directory outside the runtime home first (mode 0700).
Substitute verified paths and a new backup filename:

```bash
bash scripts/mobile/snapshot.sh --home /verified/guest/home --backup /private/backups/before.json
bash scripts/mobile/rollback.sh --home /verified/guest/home --backup /private/backups/before.json
# Only after reviewing the JSON plan:
bash scripts/mobile/rollback.sh --home /verified/guest/home --backup /private/backups/before.json --mode apply
```

Snapshots contain the five manifest-selected files' contents, permissions,
symlink targets or absence. Backups are private, never overwritten, and tied to
the exact home path and current inventory. SHA-256 detects accidental content
corruption, not malicious rewriting by someone with backup access.

Restore defaults to a non-mutating JSON plan. Apply validates the complete
inventory before writing and verifies the result. It refuses symlink ancestors,
unexpected directories, outside-inventory paths and corrupt file contents.
Unmanaged neighbors remain untouched. Originally absent managed files are removed
if now present: review that plan before apply. Parent directories are not pruned.

Each replacement is atomic, not the whole restore; an interrupted restore can be
rerun. Keep configuration quiescent during capture/restore. These helpers do not
back up package state, Android preferences or databases, and do not prove a
supplied directory belongs to Omalauncher. Device deployment remains disabled.
