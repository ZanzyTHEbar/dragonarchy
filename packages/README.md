# Dotfiles Packages

This directory contains modular package configurations managed by GNU Stow.

## Stow Configuration

### `.stow-global-ignore`

The `.stow-global-ignore` file at the root of this `packages/` directory applies to **all packages**. This prevents unwanted files from being symlinked to the home directory.

**Ignored patterns:**
- `.package` - Marker files used for package tracking
- `README.md`, `README.txt`, `README` - Documentation files
- `.git`, `.gitignore`, `.gitmodules` - Version control files
- `.vscode`, `.idea` - Editor/IDE directories
- Backup files (`*.bak`, `*.backup`, `*.swp`, `*.swo`, `*~`, etc.)

### Usage

From the `packages/` directory, stow any package:

```bash
cd ~/dotfiles/packages
stow <package-name>
```

The `.stow-global-ignore` file is automatically applied to all stow operations.

### Adding New Packages

When creating a new package:

1. Create the package directory structure:
   ```bash
   mkdir -p packages/mypackage/.config/myapp
   ```

2. Add your configuration files in the appropriate paths

3. (Optional) Add a `.package` marker file:
   ```bash
   touch packages/mypackage/.package
   ```

4. (Optional) Add a README:
   ```bash
   echo "# My Package" > packages/mypackage/README.md
   ```

5. Stow the package:
   ```bash
   cd packages
   stow mypackage
   ```

The `.package` and `README.md` files will automatically be excluded from stowing.

## Package List

Each subdirectory represents a self-contained configuration package that can be independently stowed or unstowed.

### Available Packages

Run `ls -d */` in this directory to see all available packages.

### Modifying Ignore Patterns

To add or modify global ignore patterns, edit `.stow-global-ignore` in this directory. The file uses Perl regular expressions.

**Examples:**
```
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

## Related Scripts

- `scripts/install/stow-system.sh` - System-level stow operations
- `scripts/install/setup.sh` - Main setup script
- `scripts/install/update.sh` - Update dotfiles

## More Information

- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/)
- [Main dotfiles README](../README.md)
