# Wayle desktop bar

`config.toml` owns layout, spacing, fonts, and semantic color roles. The bar uses
the selected dotfiles theme, not a separate Wayle theme selection.

`scripts/theme-manager/wayle-theme-apply` generates the runtime-owned
`~/.config/wayle/palette.toml` from the selected `hyprland-palette.conf`.
`theme-set` calls it before selecting a new theme when Wayle is configured.
Palette and provider overrides are cleared through Wayle's native config API;
unrelated GUI preferences remain intact. Runtime files are excluded from chezmoi.

Auto-hide requires the native implementation in `~/Projects/wayle` until it is
available upstream. This payload does not change autostart or replace Waybar.
