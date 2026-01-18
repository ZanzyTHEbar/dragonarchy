Name = "dragon_theme_gallery"
NamePretty = "Theme Gallery"
Icon = "view-grid"
Parent = "dragon_theme"
Description = "Browse themes with a background preview"
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

local function state_home()
    local env = os.getenv("XDG_STATE_HOME")
    if env ~= nil and env ~= "" then
        return env
    end
    local home = os.getenv("HOME") or ""
    return home .. "/.local/state"
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

local function first_background_for_theme(theme_path)
    local base = theme_path .. "/backgrounds"
    local cmd = string.format(
        "find '%s' -maxdepth 1 -type f \\( " ..
        "-iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' " ..
        "\\) 2>/dev/null | sort | head -n 1",
        base
    )
    local handle = io.popen(cmd)
    if not handle then
        return ""
    end
    local first = handle:read("*l") or ""
    handle:close()
    return first
end

local function file_exists(path)
    if path == nil or path == "" then
        return false
    end
    local f = io.open(path, "r")
    if f ~= nil then
        f:close()
        return true
    end
    return false
end

local function run_cmd_first_line(cmd)
    local handle = io.popen(cmd)
    if not handle then
        return ""
    end
    local out = handle:read("*l") or ""
    handle:close()
    return out
end

local function read_lines(path, max_lines)
    local out = {}
    if path == nil or path == "" then
        return out
    end
    local f = io.open(path, "r")
    if not f then
        return out
    end
    local n = 0
    for line in f:lines() do
        if line ~= nil then
            local s = tostring(line):gsub("%s+$", "")
            if s ~= "" then
                table.insert(out, s)
                n = n + 1
                if max_lines ~= nil and n >= max_lines then
                    break
                end
            end
        end
    end
    f:close()
    return out
end

local function contains(set, key)
    return set[key] == true
end

function GetEntries()
    local entries = {}
    local themes = list_themes()
    local current = current_theme_slug()
    local current_bg = current_background_path()

    local preview_helper = dotfiles_root() .. "/scripts/theme-manager/theme-gallery-preview"

    local fav_file = config_home() .. "/dragon/theme-favorites"
    local recents_file = state_home() .. "/dragon/theme-manager/recent-themes"

    local favorites = read_lines(fav_file, 200)
    local recents = read_lines(recents_file, 50)

    local by_slug = {}
    for _, item in ipairs(themes) do
        by_slug[item.slug] = item
    end

    -- Quick actions
    table.insert(entries, {
        Text = "Undo last theme change",
        Subtext = "Toggle back to the previous theme",
        Icon = "edit-undo",
        Actions = { ["menus:default"] = "theme-undo", undo = "theme-undo" }
    })
    table.insert(entries, {
        Text = "Revert preview session",
        Subtext = "Go back to the theme/background you had before previewing",
        Icon = "edit-undo",
        Actions = { ["menus:default"] = "theme-preview-revert", revert_preview = "theme-preview-revert" }
    })

    local seen = {}

    local function add_theme_entry(item, is_favorite, is_recent)
        local display = title_case(item.slug:gsub("-", " "))
        -- Prefer a cached composite preview (wallpaper + palette strip)
        local preview = ""
        if file_exists(preview_helper) then
            preview = run_cmd_first_line(string.format("'%s' '%s' 2>/dev/null", preview_helper, item.slug))
        end
        -- Fallback: wallpaper itself (no palette)
        if preview == "" then
            preview = first_background_for_theme(item.path)
            if current ~= "" and current == item.slug and current_bg ~= "" then
                preview = current_bg
            end
        end

        local entry = {
            Text = display,
            Subtext = item.slug,
            Value = item.slug,
            Icon = "preferences-desktop-theme",
            Actions = {
                ["menus:default"] = "theme-apply %VALUE%",
                remove = "theme-remove %VALUE%",
                favorite = "theme-favorite-toggle %VALUE%",
                undo = "theme-undo",
                preview = "theme-preview %VALUE%",
                revert_preview = "theme-preview-revert"
            }
        }

        -- Only attach preview fields when we have a valid image path.
        -- Some Walker builds will close the UI if preview_type is "file" but preview is empty/invalid.
        if file_exists(preview) then
            entry.Preview = preview
            entry.PreviewType = "file"
        end

        if current ~= "" and current == item.slug then
            entry.State = { "current" }
            entry.Subtext = "current"
        end

        if is_favorite then
            entry.State = entry.State or {}
            table.insert(entry.State, "favorite")
        end
        if is_recent then
            entry.State = entry.State or {}
            table.insert(entry.State, "recent")
        end

        table.insert(entries, entry)
        seen[item.slug] = true
    end

    -- Favorites first (in file order)
    for _, slug in ipairs(favorites) do
        local item = by_slug[slug]
        if item ~= nil and not seen[slug] then
            add_theme_entry(item, true, false)
        end
    end

    -- Recents next (in file order), skipping ones already shown as favorites
    for _, slug in ipairs(recents) do
        local item = by_slug[slug]
        if item ~= nil and not seen[slug] then
            add_theme_entry(item, false, true)
        end
    end

    -- Remaining themes (alphabetical already from list_themes)
    for _, item in ipairs(themes) do
        if not seen[item.slug] then
            add_theme_entry(item, false, false)
        end
    end

    -- Simple navigation footer
    table.insert(entries, {
        Text = "Theme Controls (advanced list)",
        Subtext = "Install / Update / Remove / Background tools",
        Icon = "preferences-desktop-theme",
        SubMenu = "dragon_theme"
    })

    return entries
end

