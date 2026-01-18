Name = "dragon_theme"
NamePretty = "Theme Controls"
Icon = "preferences-desktop-theme"
Parent = "dragon"
Description = "Manage Dragon themes and assets"
Action = "theme-set %VALUE%"
History = false
Cache = false
SearchName = true

local function dotfiles_root()
    local env = os.getenv("DOTFILES_ROOT")
    if env ~= nil and env ~= "" then
        return env
    end
    local home = os.getenv("HOME") or ""
    return home .. "/dotfiles"
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
    local themes = {}
    local base = dotfiles_root() .. "/packages/themes/.config/themes"
    local cmd = string.format("find '%s' -mindepth 1 -maxdepth 1 -type d -o -type l 2>/dev/null", base)
    local handle = io.popen(cmd)
    if not handle then
        return themes
    end
    for line in handle:lines() do
        local slug = line:match("([^/]+)$")
        if slug then
            table.insert(themes, { slug = slug, path = line })
        end
    end
    handle:close()
    table.sort(themes, function(a, b)
        return a.slug < b.slug
    end)
    return themes
end

local function current_theme_slug()
    local link = config_home() .. "/current/theme"
    local handle = io.popen(string.format("readlink -f '%s' 2>/dev/null", link))
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
            Subtext = item.slug,
            Value = item.slug,
            Icon = "preferences-desktop-theme",
            Actions = {
                ["menus:default"] = "theme-set %VALUE%",
                remove = "theme-remove %VALUE%"
            }
        }

        if current ~= "" and current == item.slug then
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
            ["menus:default"] = "theme-install %ARGS%",
            from_clipboard = "theme-install \"$(wl-paste)\""
        }
    })

    table.insert(entries, {
        Text = "Update Installed Themes",
        Icon = "view-refresh",
        Actions = {
            ["menus:default"] = "theme-update"
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
            ["menus:default"] = "theme-bg-next"
        }
    })

    return entries
end


