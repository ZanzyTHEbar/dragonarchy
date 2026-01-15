# SwayNC `config.json` Reference (Schema-Backed)

Source of truth: `/etc/xdg/swaync/configSchema.json`.
This schema is installed with SwayNC and defines every supported key and its description.

## Theme & CSS
- `$schema` (schema pointer)
- `ignore-gtk-theme` (bool)
- `cssPriority` (`application` or `user`)

## Position, Layers, Outputs
- `positionX`, `positionY`
- `control-center-positionX`, `control-center-positionY`
- `layer`, `control-center-layer`
- `layer-shell`, `layer-shell-cover-screen`
- `control-center-exclusive-zone`
- `control-center-preferred-output`
- `notification-window-preferred-output`

## Sizing & Margins
- `control-center-width`, `control-center-height`
- `notification-window-width`, `notification-window-height`
- `fit-to-screen`
- `control-center-margin-top`
- `control-center-margin-bottom`
- `control-center-margin-left`
- `control-center-margin-right`

## Notification Behavior
- `timeout`, `timeout-low`, `timeout-critical`
- `notification-2fa-action`
- `notification-inline-replies`
- `notification-body-image-height`, `notification-body-image-width`
- `notification-icon-size` (deprecated in schema)
- `notification-grouping`
- `image-visibility`
- `transition-time`
- `hide-on-clear`, `hide-on-action`
- `relative-timestamps`
- `keyboard-shortcuts`
- `text-empty`
- `script-fail-notify`

## Rules & Automation
- `scripts` (matchers + exec)
- `notification-visibility`
- `notification-action-filter`

## Widgets
- `widgets` (order + enabled widgets)
- `widget-config` (per-widget options)
  - `notifications`: `vexpand`
  - `title`: `text`, `clear-all-button`, `button-text`
  - `dnd`: `text`
  - `label`: `text`, `max-lines`
  - `mpris`: `show-album-art`, `autohide`, `blacklist`, `loop-carousel`, `image-size` (deprecated)
  - `buttons-grid`: `buttons-per-row`, `actions[]` (`label`, `command`, `type`, `update-command`, `active`)
  - `menubar`: `menu*` (`label`, `position`, `animation-type`, `animation-duration`, `actions`),
    `buttons*` (`position`, `actions`)
  - `slider`: `label`, `cmd_setter`, `cmd_getter`, `min`, `max`, `min_limit`, `max_limit`, `value_scale`
  - `volume`: `label`, `show-per-app`, `show-per-app-icon`, `show-per-app-label`,
    `expand-per-app`, `empty-list-label`, `expand-button-label`, `collapse-button-label`,
    `icon-size` (deprecated), `animation-type`, `animation-duration`
  - `backlight`: `label`, `device`, `subsystem`, `min`
  - `inhibitors`: `text`, `clear-all-button`, `button-text`

## Repo Default (Theme-Aligned)
We keep a minimal theme-aligned config at
`packages/hyprland/.config/swaync/config.json`.
All other options use SwayNC defaults from the schema.

```json
{
  "$schema": "/etc/xdg/swaync/configSchema.json",
  "ignore-gtk-theme": true,
  "cssPriority": "user"
}
```
