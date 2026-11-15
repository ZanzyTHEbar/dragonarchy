Name = "dragon_theme"
NamePretty = "Theme Controls"
Icon = "preferences-desktop-theme"
Parent = "dragon"
Description = "Manage Dragon themes and assets"
History = false
Cache = false
SearchName = true

local function installed_bin()
    return (os.getenv("HOME") or "") .. "/.local/bin"
end

local function shell_quote(value)
    -- Elephant replaces %VALUE% and then %ARGS%, even inside shell quotes.
    return "'" .. value:gsub("'", "'\\''"):gsub("%%", "%%''") .. "'"
end

-- Declared installed live API; never fall back to checkout/offline dispatch.
local function theme_helper(name)
    return shell_quote(installed_bin() .. "/" .. name)
end

Action = "[ -n ''%VALUE% ] && " .. theme_helper("theme-set") .. " %VALUE%"

-- Elephant passes args as data to Lua actions before performing substitutions.
function InstallTheme(_value, args, _query)
    local result = os.execute(theme_helper("theme-install") .. " " .. shell_quote(args))
    if result ~= 0 and result ~= true then
        error("theme-install failed")
    end
end

local function config_home()
    local env = os.getenv("XDG_CONFIG_HOME")
    if env ~= nil and env ~= "" then
        return env
    end
    local home = os.getenv("HOME") or ""
    return home .. "/.config"
end

local function title_case(str)
    local function convert(word)
        local first = word:sub(1, 1):upper()
        local rest = word:sub(2):lower()
        return first .. rest
    end
    return (str:gsub("(%a[%w']*)", convert))
end

local function list_themes()
    local handle = io.popen(theme_helper("theme-list") .. " --json")
    if not handle then
        return {}
    end
    local data = handle:read("*a")
    handle:close()
    local themes = jsonDecode(data)
    if type(themes) ~= "table" then return {} end
    table.sort(themes, function(a, b)
        return a.id < b.id
    end)
    return themes
end

local function current_theme_slug()
    local link = config_home() .. "/current/theme"
    local handle = io.popen(string.format("readlink -e %s 2>/dev/null", shell_quote(link)))
    if not handle then
        return ""
    end
    local resolved = handle:read("*l") or ""
    handle:close()
    if resolved == "" then
        return ""
    end
    local slug = resolved:match("([^/]+)$")
    return slug or ""
end

function GetEntries()
    local entries = {}
    local themes = list_themes()
    local current = current_theme_slug()

    table.insert(entries, {
        Text = "Theme Gallery (visual)",
        Subtext = "Browse themes with a background preview",
        Icon = "view-grid",
        SubMenu = "dragon_theme_gallery"
    })

    for _, item in ipairs(themes) do
        local display = title_case(item.slug:gsub("-", " "))
        local entry = {
            Text = display,
            Subtext = item.id,
            Value = shell_quote(item.id),
            Icon = "preferences-desktop-theme",
            Actions = {
                ["menus:default"] = Action,
                remove = theme_helper("theme-remove") .. " %VALUE%"
            }
        }

        if item.current then
            entry.State = { "current" }
            entry.Subtext = "current"
        end

        table.insert(entries, entry)
    end

    table.insert(entries, {
        Text = "Install Theme from Git URL",
        Subtext = "Type or paste URL, default action uses query args",
        Icon = "system-software-install",
        Actions = {
            ["menus:default"] = "lua:InstallTheme",
            from_clipboard = theme_helper("theme-install") .. " \"$(wl-paste)\""
        }
    })

    table.insert(entries, {
        Text = "Update Installed Themes",
        Icon = "view-refresh",
        Actions = {
            ["menus:default"] = theme_helper("theme-update")
        }
    })

    table.insert(entries, {
        Text = "Backgrounds (current theme)",
        Icon = "preferences-desktop-wallpaper",
        SubMenu = "dragon_backgrounds"
    })

    table.insert(entries, {
        Text = "Next Background",
        Icon = "media-skip-forward",
        Actions = {
            ["menus:default"] = theme_helper("theme-bg-next")
        }
    })

    return entries
end
