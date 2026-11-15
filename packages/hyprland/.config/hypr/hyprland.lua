-- Dragonarchy supports the current Hyprland Lua API only. No Hyprlang loader.
local version = hl.version()
local major, minor, patch = version:match("^v?(%d+)%.(%d+)%.(%d+)")
assert(major, "Cannot identify Hyprland release: " .. version)
local release = tonumber(major) * 1000000 + tonumber(minor) * 1000 + tonumber(patch)
assert(release >= 57002, "Dragonarchy requires Hyprland >= 0.57.2; upgrade Hyprland before starting this session")

local root = (os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") .. "/hypr/"
-- Missing modules and invalid/future APIs are errors, never fallback triggers.
require(root .. "colors-theme.lua")
for _, module in ipairs({"environment", "settings", "animations", "bindings", "rules", "autostart"}) do
    require(root .. "lua/" .. module .. ".lua")
end
-- These are mutable personal inputs, initialized once by theme-bootstrap.
for _, module in ipairs({"monitor", "keyboard", "user", "host"}) do
    require(root .. "local/" .. module .. ".lua")
end
-- Only dynamic-monitors publishes this output; never a personal override.
local monitor_runtime = io.open(root .. "monitor-runtime.lua", "r")
if monitor_runtime then
    monitor_runtime:close()
    require(root .. "monitor-runtime.lua")
end
