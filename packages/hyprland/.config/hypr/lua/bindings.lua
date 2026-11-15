local d = hl.dsp
local terminal = "uwsm app -- kitty"
local browser = "uwsm app -- vivaldi-stable --ozone-platform=wayland --enable-features=WaylandWindowDecorations"
hl.bind("SUPER + RETURN", d.exec_cmd(terminal), { description = "Open terminal" })
hl.bind("SUPER + E", d.exec_cmd(terminal .. " zsh -lic yazi"), { description = "Open file manager" })
hl.bind("SUPER + S", d.exec_cmd("hyprshot -m region --raw | swappy -f -"), { description = "Screen capture selection" })
hl.bind("SUPER SHIFT + V", d.window.float(), { description = "Toggle floating" })
hl.bind("SUPER + SPACE", d.exec_cmd("walker"), { description = "Application launcher" })
hl.bind("SUPER + F", d.window.fullscreen(), { description = "Toggle fullscreen" })
hl.bind("SUPER + Y", d.window.pin(), { description = "Pin window" })
hl.bind("SUPER + J", d.layout("togglesplit"), { description = "Toggle split direction" })
hl.bind("SUPER + B", d.exec_cmd(browser), { description = "Open browser" })
hl.bind("SUPER + Q", d.exec_cmd([[pkill -TERM -f "$(hyprctl activewindow -j | jq -r .class)" || sleep 3 && pkill -KILL -f "$(hyprctl activewindow -j | jq -r .class)"]]), { description = "Terminate active application processes" })
hl.bind("SUPER + C", d.window.close(), { description = "Close window" })
hl.bind("SUPER + W", d.window.kill(), { description = "Force kill active window" })
hl.bind("SUPER SHIFT + M", d.exec_cmd("uwsm stop"), { description = "Exit session" })
hl.bind("CTRL ALT + DELETE", d.exec_cmd('"$HOME/.local/bin/power-menu"'), { description = "Power menu" })

hl.bind("SUPER + V", d.exec_cmd('kitty --class clipse-enhanced "$HOME/.local/bin/clipse-wrapper"'), { description = "Quick clipboard" })
hl.bind("ALT + V", d.exec_cmd('"$HOME/.local/bin/walker-clipboard"'), { description = "Advanced clipboard" })
hl.bind("SUPER CTRL + V", d.exec_cmd('"$HOME/.local/bin/walker-clipboard"'), { description = "Walker clipboard" })
hl.bind("SUPER ALT + V", d.exec_cmd('"$HOME/.local/bin/clipboard-menu"'), { description = "Clipboard menu" })
-- Preserve the declared copy/close overlap rather than silently selecting one.
hl.bind("SUPER + C", d.send_shortcut({ mods = "CTRL", key = "Insert" }), { description = "Universal copy" })
hl.bind("SUPER SHIFT + X", d.send_shortcut({ mods = "CTRL", key = "X" }), { description = "Universal cut" })
hl.bind("SUPER + P", d.send_shortcut({ mods = "SHIFT", key = "Insert" }), { description = "Universal paste" })
hl.bind("SUPER CTRL ALT + C", d.exec_cmd([[sh -c '[ -f "$HOME/.config/clipse/clipboard_history.json" ] && rm "$HOME/.config/clipse/clipboard_history.json" && notify-send "Clipboard" "History cleared"']]), { description = "Clear clipboard history" })
hl.bind("SUPER ALT SHIFT + C", d.exec_cmd("hyprshot -m region -z --clipboard-only"), { description = "Screenshot to clipboard" })
hl.bind("SUPER SHIFT CTRL ALT + C", d.exec_cmd('"$HOME/.local/bin/dragon-clipboard-session" --restart'), { description = "Restart clipboard owner" })

hl.bind("SUPER + K", d.group.toggle(), { description = "Toggle window group" })
hl.bind("SUPER + Tab", d.group.next(), { description = "Next grouped window" })
hl.bind("SUPER ALT + Tab", d.group.prev(), { description = "Previous grouped window" })
hl.bind("SUPER SHIFT + G", function() hl.config({ general = { gaps_out = 5, gaps_in = 3 } }) end, { description = "Restore gaps" })
hl.bind("SUPER + G", function() hl.config({ general = { gaps_out = 0, gaps_in = 0 } }) end, { description = "Remove gaps" })
hl.bind("XF86AudioRaiseVolume", d.exec_cmd("moonlight-media volume-up"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", d.exec_cmd("moonlight-media volume-down"), { repeating = true, locked = true })
hl.bind("XF86AudioMute", d.exec_cmd("moonlight-media mute"), { repeating = true, locked = true })
hl.bind("XF86AudioPlay", d.exec_cmd("moonlight-media play-pause"), { description = "Play/pause" })
hl.bind("XF86AudioNext", d.exec_cmd("moonlight-media next"), { description = "Next track" })
hl.bind("XF86AudioPrev", d.exec_cmd("moonlight-media previous"), { description = "Previous track" })
hl.bind("SUPER + A", d.exec_cmd("kitty --class=Wiremix wiremix"), { description = "Audio configuration" })
hl.bind("ALT + SPACE", d.exec_cmd('"$HOME/.local/bin/keyboard-layout" switch'), { description = "Switch keyboard layout" })
hl.bind("XF86MonBrightnessUp", d.exec_cmd([[brightnessctl s +5% && v="$(brightnessctl -m | cut -d, -f4 | tr -d '%' | head -1)" && { wob="/tmp/$HYPRLAND_INSTANCE_SIGNATURE.wob"; [ -p "$wob" ] && printf "%s\n" "$v" > "$wob" || true; }]]), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", d.exec_cmd([[brightnessctl s 5%- && v="$(brightnessctl -m | cut -d, -f4 | tr -d '%' | head -1)" && { wob="/tmp/$HYPRLAND_INSTANCE_SIGNATURE.wob"; [ -p "$wob" ] && printf "%s\n" "$v" > "$wob" || true; }]]), { repeating = true, locked = true })
hl.bind("SUPER SHIFT + P", d.exec_cmd("gnome-calculator"), { description = "Calculator" })
hl.bind("SUPER + L", d.exec_cmd('"$HOME/.local/bin/power-menu" --action lock'), { description = "Lock screen" })
hl.bind("SUPER + O", d.exec_cmd("killall -SIGUSR2 waybar"), { description = "Reload Waybar" })

-- Approved native left-drag approximation; no duplicate directional mouse bind.
hl.bind("SUPER + mouse:272", d.window.drag(), { mouse = true, description = "Drag window" })
hl.bind("SUPER + mouse:273", d.window.resize(), { mouse = true, description = "Resize window" })
for _, direction in ipairs({"left", "right", "up", "down"}) do
    hl.bind("SUPER SHIFT + " .. direction, d.window.move({ direction = direction }), { description = "Move window " .. direction })
    hl.bind("SUPER + " .. direction, d.focus({ direction = direction }), { description = "Focus " .. direction })
end
hl.bind("SUPER + R", d.submap("resize"), { description = "Window resizing mode" })
hl.define_submap("resize", function()
    for _, resize in ipairs({{"right",15,0}, {"left",-15,0}, {"up",0,-15}, {"down",0,15},
                             {"l",15,0}, {"h",-15,0}, {"k",0,-15}, {"j",0,15}}) do
        hl.bind(resize[1], d.window.resize({ x = resize[2], y = resize[3], relative = true }), { description = "Resize " .. resize[1] })
    end
    hl.bind("escape", d.submap("reset"), { description = "End resizing" })
end)
for _, resize in ipairs({{"right",15,0}, {"left",-15,0}, {"up",0,-15}, {"down",0,15},
                         {"l",15,0}, {"h",-15,0}, {"k",0,-15}, {"j",0,15}}) do
    hl.bind("SUPER CTRL SHIFT + " .. resize[1], d.window.resize({ x = resize[2], y = resize[3], relative = true }), { description = "Resize " .. resize[1] })
end
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind("SUPER CTRL + " .. key, d.window.move({ workspace = i }), { description = "Move window and switch to workspace " .. i })
    hl.bind("SUPER SHIFT + " .. key, d.window.move({ workspace = i, follow = false }), { description = "Move window silently to workspace " .. i })
    hl.bind("SUPER + " .. key, d.focus({ workspace = i }), { description = "Switch to workspace " .. i })
end
hl.bind("SUPER CTRL + left", d.window.move({ workspace = "-1" }), { description = "Move to previous workspace" })
hl.bind("SUPER CTRL + right", d.window.move({ workspace = "+1" }), { description = "Move to next workspace" })
-- Preserve the declared group/monitor Tab overlap.
hl.bind("SUPER + TAB", d.focus({ monitor = "+1" }), { description = "Next monitor" })
hl.bind("SUPER SHIFT + TAB", d.focus({ monitor = "-1" }), { description = "Previous monitor" })
hl.bind("SUPER + PERIOD", d.focus({ workspace = "e+1" }), { description = "Next existing workspace" })
hl.bind("SUPER + COMMA", d.focus({ workspace = "e-1" }), { description = "Previous existing workspace" })
hl.bind("SUPER + mouse_down", d.focus({ workspace = "e+1" }), { description = "Next existing workspace" })
hl.bind("SUPER + mouse_up", d.focus({ workspace = "e-1" }), { description = "Previous existing workspace" })
hl.bind("SUPER + slash", d.focus({ workspace = "previous" }), { description = "Previous workspace" })
hl.bind("SUPER + F1", d.workspace.toggle_special("special"), { description = "Toggle special workspace" })
hl.bind("SUPER CTRL + F1", d.window.move({ workspace = "special:special" }), { description = "Move to special workspace" })
hl.bind("SUPER ALT SHIFT + F1", d.window.move({ workspace = "e+0", follow = false }), { description = "Restore from special workspace" })
hl.bind("SUPER + equal", d.workspace.toggle_special("scratchpad"), { description = "Toggle scratchpad" })
hl.bind("SUPER + minus", d.window.move({ workspace = "special:scratchpad", follow = false }), { description = "Move to scratchpad" })
hl.bind("SUPER CTRL + minus", d.window.move({ workspace = "e+0", follow = false }), { description = "Restore scratchpad window" })
hl.bind("SUPER + M", d.window.move({ workspace = "special:minimized", follow = false }), { description = "Minimize window" })
-- Preserve the declared exit/minimized overlap.
hl.bind("SUPER SHIFT + M", d.workspace.toggle_special("minimized"), { description = "Toggle minimized workspace" })
hl.bind("SUPER ALT + Y", d.exec_cmd(browser .. ' --app="https://youtube.com/"'), { description = "YouTube" })
hl.bind("SUPER ALT + G", d.exec_cmd(browser .. ' --app="https://grok.com/"'), { description = "Grok" })
hl.bind("SUPER ALT + C", d.exec_cmd(browser .. ' --app="https://chatgpt.com/"'), { description = "ChatGPT" })
hl.bind("SUPER ALT + T", d.exec_cmd(browser .. ' --app="https://tasks.google.com/tasks/"'), { description = "ToDo" })
