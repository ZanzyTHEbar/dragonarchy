# fcitx5 Configuration

This package contains the configuration for fcitx5, a flexible input method framework.

## Features

- **US-International (AltGr) Layout**: Configured for QWERTY with AltGr support for European characters
- **Tray Integration**: Shows keyboard indicator in waybar system tray
- **Minimal Setup**: Simple configuration without unnecessary input methods

## Keyboard Layout

The configuration uses `us-altgr-intl` which provides:

- Standard US QWERTY layout
- AltGr (Right Alt) + key combinations for special characters:
  - AltGr + e = é
  - AltGr + u = ú
  - AltGr + a = á
  - AltGr + c = ç
  - AltGr + 5 = €
  - And many more European characters

## Configuration Files

- **profile**: Defines the input method groups and default layout
- **config**: Main fcitx5 behavior settings
- **conf/classicui.conf**: UI appearance settings (tray icon, fonts, theme)

## Environment Variables

The following environment variables are set in Hyprland's `environment.conf`:

```bash
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
```

## Usage

### Tray Icon

The keyboard icon in the waybar tray shows:

- Current input method/layout
- Click to access fcitx5 menu
- Right-click for configuration options

### Adding More Input Methods

To add additional input methods (e.g., for CJK languages):

1. Install the required fcitx5 input method packages:

   ```bash
   # For Chinese (Simplified)
   paru -S fcitx5-chinese-addons
   
   # For Japanese
   paru -S fcitx5-mozc
   
   # For Korean
   paru -S fcitx5-hangul
   ```

2. Open fcitx5 configuration:

   ```bash
   fcitx5-configtool
   ```

3. Add your desired input methods in the GUI

### Switching Input Methods

By default, fcitx5 uses:

- No trigger key (always active for AltGr support)
- Add trigger keys in `config` if needed:

  ```bash
  TriggerKeys=Control+Space
  ```

## Customization

### Change Tray Icon Appearance

Edit `conf/classicui.conf`:

- `ShowLayoutNameInIcon`: Show layout code in tray (e.g., "us")
- `PreferTextIcon`: Use text instead of icon
- `TrayLabel`: Custom label for tray icon

### Change Font

Edit the `Font` entries in `conf/classicui.conf` to use your preferred font.

## Troubleshooting

### Input method not working in some apps

Make sure the environment variables are set. Restart Hyprland after changes.

### Can't type special characters

Verify that:

1. The profile is set to `us-altgr-intl`
2. fcitx5 is running: `ps aux | grep fcitx5`
3. Restart fcitx5: `fcitx5 -r`

### Tray icon not showing

Check:

1. `EnableTray=True` in `config`
2. Waybar tray module is enabled
3. Restart fcitx5

## Integration with Hyprland

fcitx5 is automatically started via `autostart.conf`:

```bash
exec-once = uwsm app -- fcitx5 &
```

The configuration works alongside Hyprland's native input settings in `input.conf`.
