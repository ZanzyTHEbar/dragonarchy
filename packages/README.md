# Dotfiles Packages

This directory contains canonical shared user-state payloads for the dotfiles control plane.

Managed user-state application is owned by chezmoi. The permanent flow is:

```bash
./infra/chezmoi/bin/chezmoi-sync --host <hostname>
chezmoi apply
```

or, through the top-level entrypoint:

```bash
./install --host <hostname> --user-only
```

GNU Stow metadata remains here because this tree is the historical package layout and is still useful for explicit legacy/recovery operations. Do not treat direct `stow` commands as the canonical managed-host install path.

## Chezmoi Manifest Ownership

`packages/<name>/` is source content. A file becomes managed user state only when an `infra/chezmoi/manifests/*.manifest` entry maps it into the chezmoi source tree.

When adding or changing managed user-state payloads:

1. Put the canonical file under the appropriate `packages/<name>/` tree.
2. Add or update a manifest entry under `infra/chezmoi/manifests/` if the file should be managed by chezmoi.
3. Run `./install --host <hostname> --user-only --dry-run` before applying on a real host.

Runtime-generated files, secrets, caches, and local state should stay out of manifests unless an explicit architecture decision says otherwise.

## Legacy Stow Configuration

### `.stowrc` (recommended / supported by GNU Stow)

GNU Stow (2.4.x) supports a resource file named `.stowrc`. The `.stowrc` file at the root of this `packages/` directory applies to **all stow commands run from this directory**. This prevents unwanted files (like package marker files) from being symlinked into your home directory.

**Ignored patterns:**

- `.package` - Marker files used for package tracking
- `README.md`, `README.txt`, `README` - Documentation files
- `.git`, `.gitignore`, `.gitmodules` - Version control files
- `.vscode`, `.idea` - Editor/IDE directories
- Backup files (`*.bak`, `*.backup`, `*.swp`, `*.swo`, `*~`, etc.)

### Legacy Usage

For explicit recovery or unmanaged-host work, run Stow from the `packages/` directory:

```bash
cd ~/dotfiles/packages
stow <package-name>
```

The `.stowrc` file is automatically applied to all Stow operations run from this directory.

### Adding New Payload Packages

When creating a new package:

1. Create the package directory structure:

   ```bash
   mkdir -p packages/mypackage/.config/myapp
   ```

2. Add your configuration files in the appropriate paths

3. Add or update an `infra/chezmoi/manifests/*.manifest` entry for any paths that should be managed by chezmoi.

4. (Optional) Add a `.package` marker file for legacy tooling:

   ```bash
   touch packages/mypackage/.package
   ```

#### Legacy System Packages

If a package must be installed system-wide (target: `/`) and must **not** be stowed into `$HOME`,
set the marker content to:

```bash
echo "scope=system" > packages/<pkg>/.package
```

These are historical system-Stow markers. New system state belongs in Ansible roles.

5. (Optional) Add a README:

   ```bash
   echo "# My Package" > packages/mypackage/README.md
   ```

6. For legacy/manual validation only, dry-run Stow from `packages/`:

```bash
cd packages
stow -n -v mypackage
```

The `.package` and `README.md` files will automatically be excluded from Stow.

## Package List

Each subdirectory represents a self-contained payload package that can be referenced by chezmoi manifests and, where still needed, independently stowed or unstowed for legacy/manual flows.

### Available Packages

Run `ls -d */` in this directory to see all available packages.

### Modifying Ignore Patterns

To add or modify global ignore patterns, edit `.stowrc` in this directory. Stow options in `.stowrc` are treated like default CLI options, and ignore patterns use Perl regular expressions.

**Examples:**

```bash
# Match exact filename
\.package

# Match files ending with pattern
.*\.bak$

# Match files starting with pattern
^\.git

# Match any README file
^README.*
```

### Per-Package Ignore (Advanced)

While `.stow-global-ignore` applies globally, you can also create a `.stow-local-ignore` file inside any specific package for package-specific ignore patterns. This is rarely needed.

## Troubleshooting

### Conflicts when stowing

If you get conflicts:

1. Check if the file already exists: `ls -la ~/.config/conflicting-file`
2. If it's a symlink from another package: `readlink -f ~/.config/conflicting-file`
3. Backup and remove if needed, then re-stow

### Verifying what stow will do

Use the `-n` (dry-run) flag to simulate:

```bash
cd ~/dotfiles/packages
stow -n -v <package-name>
```

This shows what links would be created without actually creating them.

### Checking if a file is being ignored

Run stow with verbose dry-run and grep for the filename:

```bash
cd ~/dotfiles/packages
stow -n -v <package-name> 2>&1 | grep <filename>
```

If the filename doesn't appear, it's being ignored.

## Host-Specific Configurations

### Professional Audio Interfaces

Audio configurations are **host-specific** and stored in `hosts/<hostname>/pipewire/`:

- **dragon host**: Audient iD22 stereo proxy configuration
- **Other hosts**: Use system default audio (no custom config needed)

**Setup Script**: `./scripts/utilities/audio-setup.sh` (auto-detects host and hardware)

**Documentation**: See [`../docs/AUDIO_CONFIGURATION.md`](../docs/AUDIO_CONFIGURATION.md)

The dragon configuration creates a virtual stereo sink that routes audio to the Audient iD22's front-left/right channels, perfect for gaming and desktop use while preserving full multi-channel capability for pro audio work.

## Application-Specific Fixes

Some applications require special configuration to work properly on Hyprland/Wayland:

### Zoom

Zoom experiences rendering issues (transparent/blurred windows) on Hyprland due to XWayland compatibility problems. A comprehensive fix is available:

- **Documentation**: [`../docs/ZOOM_HYPRLAND_FIX.md`](../docs/ZOOM_HYPRLAND_FIX.md)
- **Manual Fix**: Run `./scripts/utilities/zoom-fix.sh`
- **Automatic**: Included in setup orchestration via `scripts/install/setup/applications.sh`

The fix forces Zoom to run in X11 mode and applies compositor workarounds.

### Future Fixes

Additional application-specific fixes will be documented here as needed.

## Related Scripts

- `../infra/chezmoi/bin/chezmoi-sync` - permanent manifest-to-chezmoi sync
- `../install` - canonical managed-host entrypoint
- `scripts/install/stow-system.sh` - legacy system-level Stow operations
- `scripts/install/setup.sh` - legacy setup orchestrator
- `scripts/install/update.sh` - legacy update flow
- `scripts/utilities/zoom-fix.sh` - Zoom rendering fix for Hyprland

## More Information

- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/)
- [Main dotfiles README](../README.md)
- [Zoom Fix Documentation](../docs/ZOOM_HYPRLAND_FIX.md)
