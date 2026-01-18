Name = "dragon_backgrounds"
NamePretty = "Backgrounds"
Icon = "preferences-desktop-wallpaper"
Parent = "dragon_theme"
Description = "Pick backgrounds for the active theme"
History = false
Cache = false
Action = "theme-set-background %VALUE%"

local function config_home()
    local env = os.getenv("XDG_CONFIG_HOME")
    if env ~= nil and env ~= "" then
        return env
    end
    local home = os.getenv("HOME") or ""
    return home .. "/.config"
end

local function current_theme_path()
    local link = config_home() .. "/current/theme"
    local handle = io.popen(string.format("readlink -f '%s' 2>/dev/null", link))
    if not handle then
        return ""
    end
    local resolved = handle:read("*l") or ""
    handle:close()
    return resolved or ""
end

local function current_background_path()
    local link = config_home() .. "/current/background"
    local handle = io.popen(string.format("readlink -f '%s' 2>/dev/null", link))
    if not handle then
        return ""
    end
    local resolved = handle:read("*l") or ""
    handle:close()
    return resolved or ""
end

local function list_backgrounds(theme_path)
    local files = {}
    local base = theme_path .. "/backgrounds"
    local cmd = string.format(
        "find '%s' -maxdepth 1 -type f \\( " ..
        "-iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' " ..
        "\\) 2>/dev/null",
        base
    )
    local handle = io.popen(cmd)
    if not handle then
        return files
    end
    for line in handle:lines() do
        table.insert(files, line)
    end
    handle:close()
    table.sort(files)
    return files
end

function GetEntries()
    local entries = {}
    local theme_path = current_theme_path()
    if theme_path == "" then
        table.insert(entries, {
            Text = "No active theme",
            Subtext = "Apply a theme first",
            Icon = "dialog-warning",
            Actions = {}
        })
        return entries
    end

    local current_bg = current_background_path()
    local backgrounds = list_backgrounds(theme_path)

    if #backgrounds == 0 then
        table.insert(entries, {
            Text = "No backgrounds found",
            Subtext = theme_path .. "/backgrounds",
            Icon = "dialog-information",
            Actions = {}
        })
        return entries
    end

    for _, file in ipairs(backgrounds) do
        local name = file:match("([^/]+)$") or file
        local entry = {
            Text = name,
            Value = file,
            -- Many UIs expect icon *names* (not file paths). Use preview for the actual image.
            Icon = "image-x-generic",
            Preview = file,
            PreviewType = "file",
            Actions = {
                ["menus:default"] = "theme-set-background %VALUE%",
                undo = "theme-bg-undo"
            }
        }

        if current_bg ~= "" and current_bg == file then
            entry.State = { "current" }
            entry.Subtext = "current"
        end

        table.insert(entries, entry)
    end

    return entries
end
