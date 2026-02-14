#!/bin/bash
# Configure per-user services and user-session app daemons (Walker/Elephant)

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"

mkdir -p "$HOME/.config/systemd/user"

# --- Walker theme setup (align with theme-manager expectations) ---
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WALKER_THEMES_ROOT="$HOME/.config/walker/themes"
CURRENT_THEME_LINK="$HOME/.config/current/theme"
ACTIVE_THEME_PATH="$(readlink -f "$CURRENT_THEME_LINK" 2>/dev/null || true)"
ACTIVE_THEME_NAME="default"

is_stow_managed_link() {
    # True if PATH is a symlink resolving into our dotfiles packages tree.
    local p="$1"
    [[ -L "$p" ]] || return 1
    local resolved
    resolved="$(readlink -f "$p" 2>/dev/null || true)"
    [[ -n "$resolved" && "$resolved" == "$DOTFILES_ROOT/packages/"* ]]
}

mkdir -p "$WALKER_THEMES_ROOT"
rm -f "$WALKER_THEMES_ROOT/default.css"

if [[ -n "$ACTIVE_THEME_PATH" && -d "$ACTIVE_THEME_PATH" ]]; then
    ACTIVE_THEME_NAME="$(basename "$ACTIVE_THEME_PATH")"
    if [[ -f "$ACTIVE_THEME_PATH/walker.css" ]]; then
        mkdir -p "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME"
        if is_stow_managed_link "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/style.css"; then
            log_info "Walker theme CSS is stow-managed; skipping copy for '$ACTIVE_THEME_NAME'"
        else
            cp "$ACTIVE_THEME_PATH/walker.css" "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/style.css"
            log_success "Copied Walker CSS for theme '$ACTIVE_THEME_NAME'"
        fi
    else
        log_warning "Walker CSS not found in $ACTIVE_THEME_PATH; using default theme assets"
        ACTIVE_THEME_NAME="default"
    fi
fi

# Fallback to bundled default if no theme CSS copied
if [[ ! -f "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/style.css" ]]; then
    mkdir -p "$WALKER_THEMES_ROOT/default"
    if is_stow_managed_link "$WALKER_THEMES_ROOT/default/style.css"; then
        log_info "Walker default CSS is stow-managed; skipping install"
    else
        # Check if vendored walker theme exists before copying
        if [[ -f "$DOTFILES_ROOT/vendored/walker/resources/themes/default/style.css" ]]; then
            cp "$DOTFILES_ROOT/vendored/walker/resources/themes/default/style.css" \
            "$WALKER_THEMES_ROOT/default/style.css"
            log_success "Installed Walker default CSS"
        else
            log_warning "Walker default CSS not found at $DOTFILES_ROOT/vendored/walker/resources/themes/default/style.css; skipping"
            log_info "Walker will use its built-in default theme"
        fi
    fi
    ACTIVE_THEME_NAME="default"
fi

# Optional layout file
if [[ -n "$ACTIVE_THEME_PATH" && -f "$ACTIVE_THEME_PATH/walker.toml" ]]; then
    if is_stow_managed_link "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/layout.toml"; then
        log_info "Walker layout.toml is stow-managed; skipping copy for '$ACTIVE_THEME_NAME'"
    else
        cp "$ACTIVE_THEME_PATH/walker.toml" "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/layout.toml"
    fi
fi

mkdir -p "$WALKER_THEMES_ROOT/current"
if is_stow_managed_link "$WALKER_THEMES_ROOT/current/style.css"; then
    log_info "Walker current/style.css is stow-managed; skipping relink"
else
    ln -snf "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/style.css" "$WALKER_THEMES_ROOT/current/style.css"
fi
if [[ -f "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/layout.toml" ]]; then
    if is_stow_managed_link "$WALKER_THEMES_ROOT/current/layout.toml"; then
        log_info "Walker current/layout.toml is stow-managed; skipping relink"
    else
        ln -snf "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/layout.toml" "$WALKER_THEMES_ROOT/current/layout.toml"
    fi
else
    if is_stow_managed_link "$WALKER_THEMES_ROOT/current/layout.toml"; then
        log_info "Walker current/layout.toml is stow-managed; skipping removal"
    else
        rm -f "$WALKER_THEMES_ROOT/current/layout.toml"
    fi
fi

# Ensure Walker config references our stable theme name ("current").
# Theme selection is done by relinking ~/.config/walker/themes/current/style.css above.
WALKER_CONFIG="$HOME/.config/walker/config.toml"
if [[ -f "$WALKER_CONFIG" ]]; then
    if is_stow_managed_link "$WALKER_CONFIG"; then
        log_info "Walker config.toml is stow-managed; skipping theme assignment"
    else
        tmp_cfg=$(mktemp)
        awk -v theme="current" '
        BEGIN { updated = 0 }
        /^[[:space:]]*theme[[:space:]]*=/ && !updated {
          printf("theme = \"%s\"\n", theme);
          updated = 1;
          next;
        }
        { print }
        END {
          if (!updated) {
            printf("\ntheme = \"%s\"\n", theme);
          }
        }
        ' "$WALKER_CONFIG" >"$tmp_cfg"
        # Preserve symlinks by writing through the path instead of replacing it.
        cat "$tmp_cfg" >"$WALKER_CONFIG"
        rm -f "$tmp_cfg"
        log_success "Walker theme configured to 'current'"
    fi
else
    log_warning "Walker config.toml not found; skipped theme assignment"
fi

# --- Elephant user unit content ---
ELEPHANT_UNIT_PATH="$HOME/.config/systemd/user/elephant.service"
cat > "$ELEPHANT_UNIT_PATH" <<'EOF'
[Unit]
Description=Elephant
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
Environment=XDG_RUNTIME_DIR=%t
Environment="ELEPHANT_RUNPREFIX=uwsm app -- "
# Ensure desktopapplications provider finds .desktop files (native + Flatpak)
Environment="XDG_DATA_DIRS=/usr/share:/usr/local/share:%h/.local/share:%h/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share"
Environment=PATH=%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin
ExecStartPre=/usr/bin/systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DESKTOP_SESSION
ExecStartPre=/usr/bin/rm -f /tmp/elephant.sock
ExecStartPre=/usr/bin/bash -lc 'for i in {1..50}; do [ -n "${WAYLAND_DISPLAY}" ] && [ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ] && exit 0; sleep 0.2; done; echo "WAYLAND socket not ready"; exit 1'
ExecStart=/usr/bin/elephant
Restart=on-failure
RestartSec=1

[Install]
WantedBy=graphical-session.target
EOF
log_success "Wrote $ELEPHANT_UNIT_PATH"

# --- Elephant config: ensure correct runprefix for app launches ---
ELEPHANT_CFG_DIR="$HOME/.config/elephant"
ELEPHANT_CFG_REAL="$ELEPHANT_CFG_DIR"

if [[ -L "$ELEPHANT_CFG_DIR" ]]; then
    ELEPHANT_CFG_REAL="$(readlink -f "$ELEPHANT_CFG_DIR")"
    log_info "Elephant config symlink detected → $ELEPHANT_CFG_REAL"
fi

mkdir -p "$ELEPHANT_CFG_REAL"
mkdir -p "$ELEPHANT_CFG_REAL/providers"

if [[ -e "$ELEPHANT_CFG_REAL/elephant.toml" ]]; then
    log_info "Elephant elephant.toml already present; leaving as-is"
else
    cat > "$ELEPHANT_CFG_REAL/elephant.toml" <<'EOF'
# Force launcher prefix (overrides autodetect like systemd-run)
runprefix = "uwsm app -- "
EOF
    log_success "Wrote $ELEPHANT_CFG_REAL/elephant.toml (runprefix)"
fi

# Provider-specific overrides (desktop entries and runner)
if [[ -e "$ELEPHANT_CFG_REAL/desktopapplications.toml" ]]; then
    log_info "Elephant desktopapplications.toml already present; leaving as-is"
else
    cat > "$ELEPHANT_CFG_REAL/desktopapplications.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
    log_success "Wrote $ELEPHANT_CFG_REAL/desktopapplications.toml (runprefix)"
fi

if [[ -e "$ELEPHANT_CFG_REAL/runner.toml" ]]; then
    log_info "Elephant runner.toml already present; leaving as-is"
else
    cat > "$ELEPHANT_CFG_REAL/runner.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
    log_success "Wrote $ELEPHANT_CFG_REAL/runner.toml (runprefix)"
fi

# Duplicate provider configs under providers/ (some builds read from providers/*)
if [[ -e "$ELEPHANT_CFG_REAL/providers/desktopapplications.toml" ]]; then
    log_info "Elephant providers/desktopapplications.toml already present; leaving as-is"
else
    cat > "$ELEPHANT_CFG_REAL/providers/desktopapplications.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
    log_success "Wrote $ELEPHANT_CFG_REAL/providers/desktopapplications.toml (runprefix)"
fi

if [[ -e "$ELEPHANT_CFG_REAL/providers/runner.toml" ]]; then
    log_info "Elephant providers/runner.toml already present; leaving as-is"
else
    cat > "$ELEPHANT_CFG_REAL/providers/runner.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
    log_success "Wrote $ELEPHANT_CFG_REAL/providers/runner.toml (runprefix)"
fi

# --- Reload and enable user service ---
systemctl --user daemon-reload
systemctl --user enable --now elephant || log_warning "Failed to start elephant; ensure /usr/bin/elephant exists"

# Verify required Elephant providers are available
if command -v elephant >/dev/null 2>&1; then
  required_providers=(
    "calc"
    "todo"
    "websearch"
    "bluetooth"
    "archlinuxpkgs"
    "bookmarks"
    "symbols"
    "unicode"
    "menus:keybindings"
  )
  provider_output="$(elephant listproviders 2>/dev/null || true)"
  declare -A provider_map=()
  while IFS=';' read -r _identifier provider_name; do
    [[ -z "$provider_name" ]] && continue
    provider_map["$provider_name"]=1
  done <<<"$provider_output"

  missing_providers=()
  for provider in "${required_providers[@]}"; do
    if [[ -z "${provider_map[$provider]:-}" ]]; then
      missing_providers+=("$provider")
    fi
  done

  if [[ ${#missing_providers[@]} -gt 0 ]]; then
    log_warning "Elephant providers missing: ${missing_providers[*]}. Install matching elephant-* packages."
  else
    log_success "Elephant core providers detected: ${required_providers[*]}"
  fi
fi

# --- Thermal profile initialization service ---
THERMAL_PROFILE_UNIT="thermal-profile-init.service"
if systemctl --user list-unit-files --no-legend 2>/dev/null | grep -q "^${THERMAL_PROFILE_UNIT}"; then
    if systemctl --user enable --now "${THERMAL_PROFILE_UNIT}" >/dev/null 2>&1; then
        log_success "Thermal profile init service enabled"
    else
        log_warning "Failed to enable thermal-profile-init.service; ensure ~/.local/bin/thermal-profile-init exists"
    fi
else
    log_info "thermal-profile-init.service not present; skipping enablement"
fi

# --- Quick hints ---
log_info "Verify: systemctl --user status elephant"
log_info "If socket busy, ExecStartPre cleans /tmp/elephant.sock"


