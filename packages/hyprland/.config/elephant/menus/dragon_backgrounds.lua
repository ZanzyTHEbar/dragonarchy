Name = "dragon_backgrounds"
NamePretty = "Backgrounds"
Icon = "preferences-desktop-wallpaper"
Parent = "dragon_theme"
Description = "Pick backgrounds for the active theme"
History = false
Cache = false


local function shell_quote(value)
    -- Split percent tokens across shell quotes so Elephant's later %ARGS%
    -- substitution cannot reinterpret a literal filename or checkout path.
    return "'" .. value:gsub("'", "'\\''"):gsub("%%", "%%''") .. "'"
end

-- Declared installed live API, also used by theme/gallery actions.
local function theme_helper(name)
    return shell_quote((os.getenv("HOME") or "") .. "/.local/bin/" .. name)
end

-- Elephant substitutes Value literally before sh -c. Values below are already
-- shell-quoted; the empty-value guard also makes informational entries inert.
Action = "[ -n ''%VALUE% ] && " .. theme_helper("theme-set-background") .. " %VALUE%"

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
    local handle = io.popen(string.format("readlink -e %s 2>/dev/null", shell_quote(link)))
    if not handle then
        return ""
    end
    local resolved = handle:read("*l") or ""
    handle:close()
    return resolved or ""
end

local function current_background_path()
    local link = config_home() .. "/current/background"
    local handle = io.popen(string.format("readlink -e %s 2>/dev/null", shell_quote(link)))
    if not handle then
        return ""
    end
    local resolved = handle:read("*l") or ""
    handle:close()
    return resolved or ""
end

local function list_backgrounds(theme_path)
    local handle = io.popen(theme_helper("theme-list") .. " --backgrounds")
    if not handle then
        return {}
    end
    local data = handle:read("*a")
    handle:close()
    local files = jsonDecode(data)
    return type(files) == "table" and files or {}
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

    for _, item in ipairs(backgrounds) do
        local file = item.path
        local name = file:match("([^/]+)$") or file
        local entry = {
            Text = name,
            Value = shell_quote(file),
            -- Many UIs expect icon *names* (not file paths). Use preview for the actual image.
            Icon = "image-x-generic",
            Preview = file,
            PreviewType = "file",
            Actions = {
                ["menus:default"] = Action,
                undo = theme_helper("theme-bg-undo")
            }
        }

        if item.current then
            entry.State = { "current" }
            entry.Subtext = "current"
        end

        table.insert(entries, entry)
    end

    return entries
end
