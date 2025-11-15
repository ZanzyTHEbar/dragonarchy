# Intelligent Dual Clipboard System

A smart integration of **clipse** (fast TUI) and **Walker/Elephant** (advanced features) for the best clipboard experience.

## Architecture

```
┌─────────────────────────────────────────────────┐
│          Intelligent Clipboard System           │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────────┐         ┌─────────────────┐  │
│  │    Clipse    │         │ Walker/Elephant │  │
│  │  (Fast TUI)  │         │   (Advanced)    │  │
│  ├──────────────┤         ├─────────────────┤  │
│  │ • Quick access│         │ • Image preview │  │
│  │ • Vim bindings│         │ • Multi-line    │  │
│  │ • Pin items  │         │ • Edit content  │  │
│  │ • 100 history│         │ • LocalSend     │  │
│  └──────────────┘         │ • Pause/Resume  │  │
│                           └─────────────────┘  │
│                                                  │
│              Shared: wl-clipboard                │
│           (Wayland clipboard daemon)             │
└─────────────────────────────────────────────────┘
```

## Keybindings

| Key | Action | Tool |
|-----|--------|------|
| **Super + V** | Quick clipboard (TUI) | Clipse |
| **Super + Shift + V** | Advanced clipboard (images, multi-line) | Walker |
| **Super + Ctrl + V** | Clipboard with preview focus | Walker |
| **Super + Alt + V** | Clipboard menu (choose tool) | Menu |
| Super + C | Universal copy | System |
| Super + P | Universal paste | System |
| Super + Alt + C | Clear history | Utility |

## When to Use Each

### Use Clipse (Super + V) when you want:
- ⚡ **Fast access** - instant terminal UI
- ⌨️ **Keyboard-driven** - Vim-style navigation
- 📌 **Pin frequently used** items
- 💾 **100-item history** - persistent across reboots
- 🎯 **Simple text** - no need for preview

### Use Walker (Super + Shift + V) when you need:
- 🖼️ **Image preview** - see images before pasting
- 📄 **Multi-line text** - full preview of long content
- ✏️ **Edit before paste** - modify clipboard items
- 🌐 **LocalSend integration** - share over network
- ⏸️ **Pause/Resume** - control clipboard monitoring
- 🎨 **Native GUI** - beautiful theme-aware interface

## Configuration

### Clipse Config (`~/.config/clipse/config.json`)
```json
{
  "maxHistory": 100,
  "allowDuplicates": false,
  "keyBindings": {
    "choose": "enter",
    "togglePin": "p",
    "remove": "x",
    "quit": "q"
  }
}
```

### Walker Config (`~/.config/walker/config.toml`)
```toml
[builtins.clipboard]
avoid_line_breaks = false  # Allow multi-line preview
image_height = 400         # Larger image preview
max_entries = 100          # Match clipse capacity
hidden = false             # Enable direct access
```

## Features Comparison

| Feature | Clipse | Walker/Elephant |
|---------|--------|-----------------|
| **Speed** | ⚡⚡⚡ Instant | ⚡⚡ Fast |
| **Image Preview** | ❌ | ✅ Native |
| **Multi-line Preview** | ⚠️ Basic | ✅ Full |
| **Edit Content** | ❌ | ✅ Yes |
| **Pin Items** | ✅ Yes | ⚠️ Limited |
| **History Size** | ✅ 100 items | ✅ 100 items |
| **LocalSend** | ❌ | ✅ Yes |
| **Pause/Resume** | ❌ | ✅ Yes |
| **Keyboard Nav** | ✅ Vim-style | ✅ Standard |
| **Memory Usage** | 🟢 Low | 🟡 Medium |
| **Theme Integration** | 🟡 Terminal | ✅ Full |

## Workflow Examples

### Quick Text Snippets
```bash
# Copy something
echo "Quick snippet" | wl-copy

# Access immediately
Super + V
# Navigate with j/k, Enter to paste
```

### Working with Images
```bash
# Take screenshot (auto-copied)
Super + S  # Screenshot tool

# View and select
Super + Shift + V
# See visual preview, click or Enter to paste
```

### Editing Before Paste
```bash
# Copy something that needs modification
Super + Shift + V
# Select item
# Edit inline (if Walker supports)
# Or use external editor
```

### Sharing via LocalSend
```bash
# Copy content
Super + Shift + V
# Walker opens
# Use LocalSend integration to share
```

## Files Structure (GNU Stow)

```
packages/hyprland/
├── .config/
│   ├── clipse/
│   │   ├── clipse.toml
│   │   └── config.json
│   ├── hypr/config/
│   │   ├── keybinds-clipboard.conf
│   │   └── windowrules-clipboard.conf
│   └── walker/
│       └── config.toml (clipboard section)
└── .local/bin/
    ├── clipse-wrapper
    ├── clipboard-menu
    ├── generate-clipse-themes
    └── test-clipse-theme
```

## Setup

The clipboard system is automatically configured when you stow the hyprland package:

```bash
cd ~/dotfiles/packages
stow hyprland
```

This creates symlinks for:
- Configuration files → `~/.config/`
- Scripts → `~/.local/bin/`

## Dependencies

### Required
- `clipse` - TUI clipboard manager
- `walker` - Application launcher with clipboard module
- `elephant` - Clipboard history daemon (for Walker)
- `wl-clipboard` - Wayland clipboard utilities

### Optional
- `localsend` - For network sharing
- `fzf` - Enhanced fuzzy search (clipse)
- `kitty` - For image preview in terminal (clipse)

## Troubleshooting

### Clipse not working
```bash
# Check daemon
pgrep clipse

# Restart
pkill clipse && clipse -listen &

# Check config
cat ~/.config/clipse/config.json
```

### Walker clipboard empty
```bash
# Check Elephant service
systemctl --user status elephant

# Restart
systemctl --user restart elephant

# Check Walker config
cat ~/.config/walker/config.toml | grep -A10 clipboard
```

### Both systems not seeing clipboard
```bash
# Test wl-clipboard
echo "test" | wl-copy
wl-paste

# Check clipboard daemons
pgrep clipse
pgrep elephant
```

## Customization

### Change Clipse History Size
Edit `~/.config/clipse/config.json`:
```json
{
  "maxHistory": 200  // Increase to 200
}
```

### Change Walker Image Preview Size
Edit `~/.config/walker/config.toml`:
```toml
[builtins.clipboard]
image_height = 600  # Larger preview
```

### Add Custom Keybindings
Edit `~/.config/hypr/config/keybinds-clipboard.conf`:
```conf
bindd = $mainMod SHIFT ALT, V, Custom clipboard action, exec, your-command-here
```

## Best Practices

1. **Use Clipse for speed** - Daily text clipboard needs
2. **Use Walker for rich content** - Images, long text, editing
3. **Pin important items** in Clipse - Quick access to frequently used
4. **Clear history regularly** - `Super + Alt + C` or clipboard-menu
5. **Monitor memory** - Both systems cache clipboard data

## Future Enhancements

Possible additions:
- [ ] Sync clipboard between clipse and Walker
- [ ] Smart context switching (auto-use Walker for images)
- [ ] OCR integration for image text extraction
- [ ] Encryption for sensitive clipboard items
- [ ] Cloud sync for cross-device clipboard

---

**Quick Reference:**
- Fast text: `Super + V` (Clipse)
- Images/editing: `Super + Shift + V` (Walker)
- Menu: `Super + Alt + V`
