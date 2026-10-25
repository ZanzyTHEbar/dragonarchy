# Theme Manager Integration Contract

## Purpose

The theme manager is a legacy subsystem under `scripts/theme-manager/` that generates runtime color themes for multiple UI targets from static palettes.

This document defines the explicit ownership boundary between the theme-manager subsystem and the new Ansible + chezmoi control plane. Without this contract, the same paths could be modified by both the theme manager at runtime and chezmoi during apply, leading to non-deterministic user state and silent overwrites.

The contract establishes:

- which paths the theme manager may write to
- which paths are owned by chezmoi and must be treated as read-only
- how the theme manager gates its behavior against the active control-plane mode

## Ownership matrix

| Concern | Legacy Path | Canonical Owner | Notes |
|---------|-------------|-----------------|-------|
| Theme palettes and shipped application assets | `packages/themes/` → `~/.config/dragon/theme-inputs/` | chezmoi | Read-only inputs for runtime preparation, never generator output destinations |
| Wallpaper defaults | `packages/hyprland/.config/theme-manager/wallpaper.conf` → `~/.config/dragon/wallpaper.defaults.conf` | chezmoi | Bootstrap initializes mutable `theme-manager/wallpaper.conf` only when absent |
| btop defaults | `packages/hyprland/.config/btop/btop.conf` → `~/.config/dragon/btop.defaults.conf` | chezmoi | Engine initializes mutable `btop/btop.conf` only when absent; never continuously applies user preferences |
| GTK3/4 CSS | `scripts/theme-manager/generate-gtk-themes` → `~/.config/gtk-3.0/gtk.css` | **Runtime** (theme-manager) | Generated from palette |
| Kitty colors | `scripts/theme-manager/generate-kitty-themes` → `~/.config/kitty/colors.conf` | **Runtime** (theme-manager) | Generated from palette |
| SwayNC structural base | `packages/hyprland/.config/swaync/style-base.css` → `~/.config/swaync/style-base.css` | chezmoi (`session-shell`) | Immutable renderer input, retained with new generations |
| SwayNC CSS | `scripts/theme-manager/generate-swaync-themes` / installed shared engine → `~/.config/swaync/style.css` | **Runtime** (theme-manager) | Complete regular stylesheet; excluded from chezmoi |
| Clipse theme | `scripts/theme-manager/generate-clipse-themes` → `~/.config/clipse/theme.toml` | **Runtime** (theme-manager) | Already excluded from chezmoi |
| Walker CSS | `scripts/theme-manager/generate-walker-themes` → `~/.config/walker/themes/current/style.css` | **Runtime** (theme-manager) | Excluded from chezmoi manifests |
| btop theme | `generate-btop-themes` / installed shared engine → `~/.config/btop/themes/current.theme` | **Runtime** (theme-manager) | Prepared regular file; explicitly excluded from chezmoi manifests |
| wlogout CSS | `scripts/theme-manager/wlogout-setup` → `~/.config/wlogout/wlogout.css` | **Runtime** (theme-manager) | Excluded from chezmoi manifests |
| Plymouth theme | `/usr/share/plymouth/themes/` | **Ansible** | System policy/activation; legacy refresh helpers are not managed bootstrap owners |
| SDDM theme | `/usr/share/sddm/themes/` | **Ansible** | System policy/activation; no user bootstrap writes |
| Wallpaper | `scripts/theme-manager/theme-bg-*` → `~/.config/hypr/config/wallpaper.conf` | **Runtime** (theme-manager) | User-selected |
| Hyprland colors | `scripts/theme-manager/theme-set` → `~/.config/hypr/colors-theme.conf` | **Runtime** (theme-manager) | Excluded from chezmoi manifests |
| Keyboard local | `scripts/install/setup/keyboard.sh` → `~/.config/hypr/config/keyboard.local.conf` | **Runtime** (theme-manager or user) | Excluded from chezmoi manifests |
| GTK settings | `scripts/theme-manager/generate-gtk-themes` → `~/.config/gtk-3.0/settings.ini` | **Runtime** (theme-manager) | Generated from palette |
| GTK4 settings | `scripts/theme-manager/generate-gtk-themes` → `~/.config/gtk-4.0/settings.ini` | **Runtime** (theme-manager) | Generated from palette |

## Runtime-owned path contract

1. Theme-manager may write to any path marked **Runtime** in the ownership matrix.
2. Theme-manager **MUST NOT** write to chezmoi-owned paths.
3. Theme-manager scripts **MUST** source `scripts/lib/control-plane-mode.sh` before writing to any path that might overlap with chezmoi-owned trees.
4. Runtime-owned paths **MUST** be explicitly excluded from chezmoi manifests and apply operations.
5. Validate prepared inputs before publication and preserve the previous usable selection on ordinary preparation errors. Do not claim that independently written paths or all application outputs are crash-atomic.

## Managed offline preparation (Saga 1414 / 1415 / 1417 / 1418)

`session-core.manifest` installs curated themes (including shipped app assets/backgrounds), wallpaper defaults and the real executable `~/.local/bin/theme-bootstrap`. Only inventory `host_desktop_stack: hyprland` selects these inputs. Static inputs are read-only **to runtime consumers**, not writable renderer scratch space; no extra filesystem permission/security boundary is implied.

After successful user `chezmoi apply`, `install` (local) and `scripts/lib/remote-sync.py` (remote target) invoke the installed helper with the selected user's home/config destination. A bootstrap failure fails the apply command before its user-completion message. Dry-run/preview, system-only, headless and mobile paths do not execute it. The existing five-field target tuple and frozen inventory selection remain unchanged. The engine uses Python's standard library; installed canonical renderers use Bash and ordinary awk/sed/core utilities. No checkout, controller path, D-Bus or service commands are needed.

The guarantee is **after successful apply, before the next managed login/config read**: both compositor includes, Kitty colors, GTK3/4 CSS, btop's current theme and SwayNC's complete stylesheet exist. There is no new session launcher, per-login hook, concurrent-login protection or deleted-state self-healing guarantee. No actual native home apply or compositor login has yet been qualified.

With no selection, bootstrap uses the legacy declared default `tokyo-night`. Existing symlink selections use their actual source palette, including external/custom themes with familiar basenames. Runtime snapshots end in the selected slug for existing basename consumers and record the source for repeat/update preparation. Invalid/dangling selections, unsupported assets/palettes and conflicting palette state fail rather than silently resetting a theme. Existing wallpaper/background selection, GTK settings and GUI preferences are not rewritten; only an absent wallpaper configuration is initialized. Unsupported selection directories must be explicitly reconciled, not removed automatically.

Bootstrap and installed `theme-set [--no-gui] SLUG` / `theme-undo` share one engine and a persistent user-owned `current/.theme-bootstrap.lock` with Linux `flock` through publication, rollback and temporary cleanup. The lock does not coordinate interactive legacy helpers, chezmoi/static-input writers or concurrent logins. Runtime directory ancestors must not be symlinks or non-directories; overlapping source/runtime trees and non-regular/non-directory assets fail closed.

Under the acquired selection lock, overlap protection derives from **every** output/default destination parent, plus current selection/palette identity/snapshots and explicit-operation history parents. Sources equal to, containing or contained by those roots fail before destination-directory creation or renderer staging. This includes btop, Kitty and GTK, not only compositor/wallpaper paths; ordinary custom sources and installed `dragon/theme-inputs` remain supported. Bootstrap still neither consults nor creates interactive history. An invalid externally selected link is left as-is on failure, not reset to a guessed prior selection.

Content identity covers actual source paths/assets/modes/bytes, installed engine and renderer bytes, not timestamps or generated GTK preferences. Unchanged selection adds no generation/history churn. Snapshots retain original `input/` assets separately from rendered output and absolute source provenance; no pruning or database is introduced. A small published-palette digest distinguishes previously prepared regular output from conflicting manual palette state when an external selection is adopted.

The manifest installs the exact canonical `generate-kitty-themes`, `generate-gtk-themes`, `generate-btop-themes`, `generate-swaync-themes` and `lib/theme-utils.sh` under `~/.local/libexec/dragon/theme-manager/`. A shared manifest admission helper allows precisely these five script sources, not all of `scripts/`; the remote builder reuses that helper. Checked renderers receive explicit `THEMES_DIR` pointing only to a temporary selected-theme tree, plus an allowlisted environment of filesystem roots, command lookup and locale; shell startup hooks and GUI/session endpoints are not inherited. No renderer writes into installed inputs or the checkout. SwayNC additionally receives explicit `SWAYNC_BASE` pointing to the captured structural base; GTK generation needs no static settings base. Only CSS is published: generated per-theme settings are not applied, so no unverified `adw-gtk3` provider or GTK family is forced; existing settings/preferences remain untouched.

Before selection/history publication, the engine validates output files and destinations and prepares destination-local regular files for compositor colors, Kitty colors and GTK3/4 CSS. Ordinary publication errors restore previous published files/links and selection while holding the lock; this is **not cross-file crash atomicity or an all-app transaction**. Distinct snapshots remain for recovery. History stays at `$XDG_STATE_HOME/dragon/theme-manager`: `recent-themes` retains unique newest-first slugs capped at ten, `prev-theme` retains its slug format, and `previous-generation` records precise snapshot identity for undo, including custom same-basename themes. Undo toggles exact retained generations; bootstrap subsequently follows their actual source for updates. A pre-existing external selection must first be captured with `theme-bootstrap` before set/undo, rather than silently losing recoverable identity. Legacy slug-only history is not guessed into a custom source.

Automatic bootstrap never reads, validates, creates or rewrites interactive history paths, including on first preparation or changed source/renderer generations. Only explicit set/undo operations publish history alongside a meaningful selection change. A same-source set that refreshes changed inputs/renderers preserves the previous user selection/history; generation refresh is not a new user choice.

Palette validation intentionally supports only the reused canonical parser's subset: LF-separated declarations with ASCII variable names and **separate** `$name`, `=` and `rgba(HEX)` fields, separated by one or more ASCII spaces/tabs. Optional leading/trailing spaces/tabs, blank lines and `#` comments are supported; HEX is six or eight hexadecimal digits. Duplicate declarations and missing required compositor colors fail. Compact assignments such as `$background=rgba(...)` or `$background =rgba(...)`, Unicode field/leading whitespace and Unicode-only line separators are not normalized into accepted input. Original valid source bytes are retained. Unsupported declarations fail before staging/publication so pre-existing app assets cannot mask a renderer silently skipping an unreadable palette.

These installed commands perform **offline file preparation only**, including with `--no-gui`. They invoke no GSettings, signals, services, Walker, wallpaper or system-theme commands. No menu/live-refresh alias is installed. Existing checkout helpers remain until their remaining consumers are replaced: Walker's stylesheet input is absent, Clipse's actual JSON consumer does not establish consumption of the TOML generator, and wlogout/wallpaper/menu/live retint are outside this bounded renderer closure. Running-application refresh and native effects remain unqualified.

### btop preparation and retained-generation compatibility (Saga 1417)

Parent actual-source review and independent read-only confirmation (`ses_e902b0e9effeEdf0IFIhX80yFq`, reviewer executed nothing) accepted this bounded repository/offline scope after resolving the source-overlap blocker; no remaining blocker within that confirmation. Parent posted acceptance and externally marked Saga 1417 **DONE**. Worker `ses_e9032867fffee1JtMbiTLIaK2U`, result receipt `/tmp/opencode/theme-1417-result.lQM6Yr/result.md`; all owned jobs finished. This is not native btop consumption proof: Saga 1405 remains **BLOCKED**, fleet rows remain open, and the historical unknown controller-history state/user leave-as-is disposition is not called recovered.

btop is already required by `core_cli` on apt/pacman; preparation is not gated on binary presence. The renderer requires explicit `THEMES_DIR`, validates the same strict palette grammar/required background, foreground, accent, comment and green colors, and writes only each staged `btop.theme`. Optional semantic colors fall back deterministically to accent. Roles/format follow shipped btop themes and installed share examples; no native parser/runtime consumption is claimed. Inherited staging `btop.theme` is removed before rendering, so a stale shipped asset cannot mask failure. Renderer bytes participate in content identity and the required regular/nonempty output participates in the existing publication/rollback.

Only static `dragon/btop.defaults.conf` is managed. The engine initializes absent `btop/btop.conf` from those bytes (`color_theme = "current"`) without serializing settings or overwriting an existing file; an existing preference selecting another theme remains the user's choice, not a retint claim. Both wallpaper and btop defaults are validated/prepared with outputs before publication and installed by exclusive links before changing selection. Initialization/publication failure rolls back defaults created by this invocation on ordinary exceptions; directories and an already retained unselected snapshot may remain. Existing preferences are never rewritten. This adjacent wallpaper-default ordering correction avoids initializing one consumer before other outputs are prepared. External preference writers and crash atomicity remain outside the lock/rollback guarantee.

Undo to a pre-extension retained generation missing btop renders **only** that output from its retained palette in temporary runtime staging, never today's source palette. Retained compositor/Kitty/GTK bytes, selection identity, provenance and historical snapshots/input remain untouched. The same fallback handles an otherwise unchanged generation missing btop without creating a new snapshot; repeated preparation does not churn generations/history. A real source/engine/renderer identity change still causes normal bootstrap refresh once, not a blanket regeneration during undo. No migration registry, snapshot mutation or GC is introduced. History/bootstrap exclusion and the prior leave-unchanged controller-history disposition remain unchanged.

Saga 1415 validation previously wrote controller history through inherited `XDG_STATE_HOME`; original contents remain unknown. The user's **leave unchanged** disposition preserves those files as-is, with no restoration/deletion or live recovery authorized. The corrected single acceptance flow uses a minimal allowlisted environment for every child (including inventory, tar and source sync), fixture-contained HOME/XDG config/state/cache/data/runtime/TMPDIR, trusted system PATH and UTF-8 locale, with containment checks before execution. This is environment/path isolation, **not OS sandboxing**. Correction checks found no further protected-history changes at their before/after boundaries; the original incident is not called recovered. Parent final-source review and independent read-only confirmation resolved the parser finding and accepted the bounded repository/offline Kitty/GTK selection+undo scope; parent marked Saga 1415 **DONE**. The independent reviewer performed no execution. Saga 1414 is **DONE**, native qualification 1405 remains **BLOCKED**, and broader desktop/fleet closure is not established.

### Complete SwayNC preparation (Saga 1418, accepted)

Parent production/scenario/result review and independent final-source confirmation (`ses_e8c67ad6bffeJz7tcPKbNr9dj5`, reviewer executed nothing) resolved the configured-base regression below with no other blocker within reviewed scope. Parent posted bounded repository/GTK4-parser acceptance and externally marked Saga 1418 **DONE**. Worker `ses_e8c76b3bcffeTcor5PSzKYh11M`, receipt `/tmp/opencode/theme-1418-result.LgTFDxzu/result.md`; all owned jobs finished. Finalization changes documentation/private receipt only, with no full-suite rerun. Native Saga 1405 remains blocked, fleet rows remain open, no live-effects proof is claimed, and historical unknown controller history/leave-as-is disposition is not recovered.

Read-only controller metadata identifies selected Arch `swaync` **0.12.6-1.1** (`pacman -Qi`) and ELF linkage to `libgtk-4.so.1` (`readelf -d`), not GTK3. Installed GTK4 is **4.24.1** and python-gobject **3.58.1-1**. A headless `Gtk.CssProvider` parsed a complete actual installed-engine stylesheet from a newly supplied palette with **zero parsing errors**, without initializing GTK or opening a display/session. This establishes that parser boundary only, not daemon consumption, other distribution versions, visual rendering, live reload or fleet qualification. No dependency/provider/version pin was added; GI is used only by private local acceptance, not required by the repository suite.

The existing structural base uses GTK named colors, preserving layout/opacity. Previously undefined borders now explicitly use `1px solid @noti-border-color`, the existing foreground-at-15%-opacity palette role. The canonical renderer validates palettes with the shared strict validator (also reused by btop), emits named colors and appends the explicit base. Its optional checkout default remains for direct checkout callers; installed and legacy selection callers pass their owned input explicitly. Missing/nonregular/empty base, invalid palette and failed output writes fail; inherited staging `swaync.css` is removed before checked generation. Legacy `theme-set` resolves its existing `$HOME/.config/swaync/style-base.css` (including legitimate Stow symlinks) and passes the resolved regular input as `SWAYNC_BASE`, then copies successful complete output instead of composing it again. Missing configured input reports failure and preserves prior SwayNC output, without checkout fallback; legacy HOME binding and later refresh behavior remain unchanged. Only its extracted SwayNC block was executed in private acceptance, never the whole live helper.

Base name, mode and bytes join source/engine/renderer content identity. New snapshots retain the exact regular `style-base.css` beside `input/`, provenance and rendered theme; this outside-input record distinguishes owned complete output from inherited shipped colors-only assets. Exact undo publishes retained output with its retained base, even after today's static base changes. For a missing output with a retained base, only SwayNC is re-rendered using that base. Older snapshots with no such record always receive a temporary SwayNC-only render from their retained palette and today's declared base, even if they contain an inherited `swaync.css`. No nonexistent historical structure is claimed recovered. Runtime `current/.swaync-base-source` records the base path and SHA-256 used; old snapshots, other rendered outputs, original identity and undo/history are unchanged. Normal bootstrap identity refresh still occurs on genuine current-input changes. No migration registry or snapshot mutation is introduced.

The same installed/archive acceptance flow covers complete publication, palette/structure, base-only identity changes, immutable inputs/preferences, no-op/history, actual renderer/base failure and retained undo including old colors-only assets. Private headless GTK acceptance additionally parses complete published output and checks standalone invalid-palette failure. Result/commands: `/tmp/opencode/theme-1418-result.LgTFDxzu/result.md`. Rows 6/7/12 remain partial; Saga 1405/native apply and next-login/live consumption remain blocked/deferred. Next: establish remaining selected-runtime live-refresh ownership before replacing checkout-bound consumers.

## Existing live menu boundary (Saga 1416)

`dragon_theme.lua` and `dragon_theme_gallery.lua` remain **checkout-owned live menus**, enumerating `$DOTFILES_ROOT/packages/themes/.config/themes` (default `$HOME/dotfiles`). Their top-level and entry actions explicitly invoke shell-quoted paths under that same checkout's `scripts/theme-manager/`, including set/apply/undo/preview/revert and adjacent install/remove/update/favorite/next-background helpers. Missing helpers fail directly; there is no PATH fallback to installed offline `~/.local/bin/theme-set` or `theme-undo`. This preserves live behavior rather than silently changing menus to offline preparation. Discovery/preview paths also support spaces/apostrophes; Elephant `%VALUE%`/`%ARGS%` substitution is unchanged.

This fixes a backend collision, **not managed checkout-independent menu closure**. The installed engine owns offline compositor/Kitty/GTK CSS/btop/SwayNC preparation. Legacy helpers remain live consumers with their existing dependencies, uncoordinated locking/history and potentially GUI/system effects; binding their paths neither authorizes execution nor makes mixed offline/live use transactional. Ancillary install/remove/update semantics are unchanged (including update's required host/user arguments and existing external-theme discovery limitations). The separate `dragon_backgrounds` submenu and helper-internal PATH collaborators remain outside this bounded change. No Walker stylesheet, Gum/provider or desktop-runtime adoption is supplied. Selected runtime remains Waybar/SwayNC/Walker; Wayle is a pilot, Quickshell an approved direction, not a selected implementation.

## Integration with control-plane gating

Theme-manager scripts should source `scripts/lib/control-plane-mode.sh` and respect `DOTFILES_USER_OWNER=chezmoi`.

When chezmoi owns user state, the theme-manager must still fulfill its runtime contract:

- continue generating runtime files (its canonical responsibility)
- not attempt to modify static chezmoi-owned files directly
- use installed static inputs as a **read-only reference** for palette data; any future generation must target a selected-theme runtime staging tree

Managed system-level paths (Plymouth, SDDM) remain Ansible-owned. Legacy system refresh helpers are not authorization for a second managed writer.

## Runtime exclusions

The following paths are owned by the theme manager at runtime and must remain excluded from chezmoi manifests:

- `~/.config/btop/themes/current.theme`
- `~/.config/walker/themes/current/style.css`
- `~/.config/kitty/colors.conf`
- `~/.config/gtk-3.0/gtk.css`
- `~/.config/gtk-3.0/settings.ini`
- `~/.config/gtk-4.0/gtk.css`
- `~/.config/gtk-4.0/settings.ini`
- `~/.config/hypr/config/keyboard.local.conf`
- `~/.config/hypr/config/monitor.local.conf`
- `~/.config/hypr/config/workspace-indicator.local.conf`
- `~/.config/hypr/config/wallpaper.conf`
- `~/.config/hypr/colors-theme.conf`
- `~/.config/zsh/autosuggest-theme.zsh`
- `~/.config/swaync/style.css`
- `~/.config/clipse/theme.toml`
- `~/.config/wlogout/wlogout.css`
- `~/.config/current/` (selection, background and snapshots; not mapped)
- `~/.config/theme-manager/wallpaper.conf` (mutable preferences; not mapped)
- `~/.config/btop/btop.conf` (mutable preferences; only `dragon/btop.defaults.conf` mapped)

## Future work

Next: establish remaining selected-runtime renderer inputs/live-refresh ownership and checkout-independent menu consumption before replacing these checkout-bound consumers with the installed shared backend. Do not port legacy wholesale or invent a Walker stylesheet/provider. Native clean-home apply/repeat/update and next-login/config-read consumption still require separate authorization. Do not move mutable GUI preferences into continuously applied static templates.

The theme-manager remains the canonical owner of runtime theme state until a future design document overrides this contract.
