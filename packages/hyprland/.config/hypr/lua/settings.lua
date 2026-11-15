local c = require((os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") .. "/hypr/colors-theme.lua")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.config({
    general = {
        gaps_in = 3, gaps_out = 5, border_size = 2, layout = "dwindle",
        col = { active_border = c.accent, inactive_border = c.background },
        snap = { enabled = true },
    },
    decoration = {
        active_opacity = 1, rounding = 6,
        shadow = { enabled = true, range = 2, render_power = 3, color = "rgba(1a1a1aee)" },
        blur = { enabled = true, size = 3, passes = 1, vibrancy = 0.1696 },
    },
    input = {
        follow_mouse = 0, float_switch_override_focus = 0,
        kb_layout = "us,pt", kb_variant = "altgr-intl,", kb_options = "compose:menu",
        repeat_rate = 40, repeat_delay = 600, sensitivity = 0.6,
        accel_profile = "flat", force_no_accel = false,
        touchpad = {
            natural_scroll = true, clickfinger_behavior = true,
            ["tap-to-click"] = true, ["tap-and-drag"] = true,
            drag_lock = 0, scroll_factor = 0.5,
            disable_while_typing = true, middle_button_emulation = true,
        },
    },
    group = {
        col = { border_active = c.accent, border_inactive = c.background,
                border_locked_active = c.green, border_locked_inactive = c.comment },
        groupbar = {
            font_family = "CaskaydiaMono Nerd Font", text_color = c.foreground,
            col = { active = c.accent, inactive = c.background,
                    locked_active = c.green, locked_inactive = c.comment },
        },
    },
    misc = {
        font_family = "CaskaydiaMono Nerd Font", splash_font_family = "CaskaydiaMono Nerd Font",
        disable_hyprland_logo = true, col = { splash = c.accent },
        background_color = c.background, enable_swallow = false,
        swallow_regex = "^(cachy-browser|firefox|vivaldi-stable|nautilus|nemo|thunar|btrfs-assistant.)$",
        focus_on_activate = false, vrr = 2,
    },
    render = { direct_scanout = 1, cm_enabled = true, cm_auto_hdr = 0 },
    dwindle = { special_scale_factor = 0.8, preserve_split = true },
    master = { new_status = "master", special_scale_factor = 0.8 },
    xwayland = { force_zero_scaling = true },
    binds = { allow_workspace_cycles = true, workspace_back_and_forth = true,
              workspace_center_on = 1, movefocus_cycles_fullscreen = true,
              window_direction_monitor_fallback = true },
})
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up", action = "fullscreen", mode = "maximize" })
hl.gesture({ fingers = 4, direction = "down", action = "float" })
