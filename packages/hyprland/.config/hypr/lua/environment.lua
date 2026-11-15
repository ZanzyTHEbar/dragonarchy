-- Explicit strings: shell expansion is not a Lua environment API.
local home = assert(os.getenv("HOME"))
local runtime = assert(os.getenv("XDG_RUNTIME_DIR"), "A graphical runtime directory is required")
local environment = {
    HYPRCURSOR_SIZE = "22", XCURSOR_SIZE = "22", QT_CURSOR_SIZE = "24",
    HYPRCURSOR_THEME = "Bibata-Modern-Ice", XCURSOR_THEME = "Bibata-Modern-Ice",
    GDK_BACKEND = "wayland,x11,*", QT_QPA_PLATFORM = "wayland;xcb",
    QT_STYLE_OVERRIDE = "kvantum", SDL_VIDEODRIVER = "wayland",
    MOZ_ENABLE_WAYLAND = "1", ELECTRON_OZONE_PLATFORM_HINT = "wayland", OZONE_PLATFORM = "wayland",
    XDG_CURRENT_DESKTOP = "Hyprland", XDG_SESSION_TYPE = "wayland", XDG_SESSION_DESKTOP = "Hyprland",
    QT_QPA_PLATFORMTHEME = "qt5ct", QT_WAYLAND_DISABLE_WINDOWDECORATION = "1",
    QT_AUTO_SCREEN_SCALE_FACTOR = "1", GDK_SCALE = "1", XCOMPOSEFILE = home .. "/.XCompose",
    QT_IM_MODULE = "fcitx", XMODIFIERS = "@im=fcitx", SDL_IM_MODULE = "fcitx", GLFW_IM_MODULE = "ibus",
    SSH_AUTH_SOCK = runtime .. "/gcr/ssh",
    RADV_PERFTEST = "gpl,nggc,sam", AMD_VULKAN_ICD = "RADV", DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1 = "1",
    PROTON_ENABLE_NVAPI = "1", PROTON_HIDE_NVIDIA_GPU = "0", PROTON_ENABLE_NGX_UPDATER = "1",
    PROTON_ENABLE_WAYLAND = "1", mesa_glthread = "true", MESA_NO_ERROR = "1",
    __GL_THREADED_OPTIMIZATION = "1", __GL_SHADER_DISK_CACHE = "1", __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1",
}
for name, value in pairs(environment) do hl.env(name, value) end
