#!/usr/bin/env bash
#
# icons.sh - Icon deployment helpers (Dragon icons, aliases, PNG fallbacks)
#
# Callers must set these variables before invoking:
#   CONFIG_DIR  - repo root (for assets/dragon/icons)
#   SCRIPTS_DIR - scripts/ directory (for theme-manager/dragon-icons.sh)
#
# Requires: logging.sh, install-state.sh

_icons_sudo() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

refresh_icon_cache() {
    local cache_root="/usr/share/icons/hicolor"

    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        log_info "Refreshing GTK icon cache..."
        _icons_sudo gtk-update-icon-cache -f "$cache_root"
        return 0
    fi

    if command -v xdg-icon-resource >/dev/null 2>&1; then
        log_info "Refreshing icon resources via xdg-icon-resource..."
        _icons_sudo xdg-icon-resource forceupdate --theme hicolor
        return 0
    fi

    log_warning "No icon cache refresh command available (gtk-update-icon-cache or xdg-icon-resource)"
    return 0
}

deploy_dragon_icons() {
    log_step "Deploying Dragon Control icons..."

    local generator="$SCRIPTS_DIR/theme-manager/dragon-icons.sh"
    if [[ ! -x "$generator" ]]; then
        log_error "Dragon icon generator not found at $generator"
        return 1
    fi

    local assets_step_id="assets:dragon-icons"
    local assets_root="$CONFIG_DIR/assets/dragon/icons/hicolor"
    local expected_sizes=(16 24 32 48 64 96 128 192 256 512)

    local missing_any="false"
    local size icon_path
    for size in "${expected_sizes[@]}"; do
        icon_path="${assets_root}/${size}x${size}/apps/dragon-control.png"
        if [[ ! -f "$icon_path" ]]; then
            missing_any="true"
            break
        fi
    done

    if [[ "$missing_any" != "true" ]]; then
        if is_step_completed "$assets_step_id"; then
            log_info "Dragon icon assets already generated; skipping generation ($assets_step_id)"
        else
            log_info "Dragon icon assets already present; marking generation step completed ($assets_step_id)"
            mark_step_completed "$assets_step_id"
        fi
    else
        log_info "Dragon icon assets missing; generating icon variants..."
        "$generator"

        for size in "${expected_sizes[@]}"; do
            icon_path="${assets_root}/${size}x${size}/apps/dragon-control.png"
            if [[ ! -f "$icon_path" ]]; then
                log_error "Dragon icon generation incomplete; missing expected asset: $icon_path"
                return 1
            fi
        done
        mark_step_completed "$assets_step_id"
    fi

    local src_root="$CONFIG_DIR/assets/dragon/icons/hicolor"
    local dst_root="/usr/share/icons/hicolor"

    if [[ ! -d "$src_root" ]]; then
        log_error "Icon assets directory missing at $src_root"
        return 1
    fi

    local copied=false
    while IFS= read -r -d '' src; do
        local rel="${src#$src_root/}"
        if [[ -z "$rel" || "$rel" == "$src" ]]; then
            continue
        fi
        local dst="$dst_root/$rel"
        _icons_sudo install -Dm644 "$src" "$dst"
        copied=true
    done < <(find "$src_root" -type f -name "dragon-control.png" -print0)

    if [[ "$copied" != "true" ]]; then
        log_error "No Dragon icon variants were staged for installation"
        return 1
    fi

    refresh_icon_cache
    log_success "Dragon Control icons deployed"
}

deploy_icon_aliases() {
    log_step "Deploying icon aliases..."

    local dst_dir="/usr/share/icons/hicolor/scalable/apps"
    local aliases=(
        "cachy-update.svg:cachy-update-blue.svg"
        "cachy-update_updates-available.svg:cachy-update_updates-available-blue.svg"
        "arch-update-blue.svg:cachy-update-blue.svg"
        "arch-update_updates-available-blue.svg:cachy-update_updates-available-blue.svg"
    )

    local did_any=false
    local pair dst_name src_name src_path dst_path
    for pair in "${aliases[@]}"; do
        dst_name="${pair%%:*}"
        src_name="${pair##*:}"
        src_path="$dst_dir/$src_name"
        dst_path="$dst_dir/$dst_name"

        if [[ ! -e "$dst_path" && -e "$src_path" ]]; then
            _icons_sudo ln -s "$src_name" "$dst_path"
            did_any=true
            log_success "Aliased icon: $dst_name -> $src_name"
        fi
    done

    if [[ "$did_any" == "true" ]]; then
        refresh_icon_cache
        log_success "Icon aliases deployed"
    else
        log_info "No icon aliases needed"
    fi
}

deploy_icon_png_fallbacks() {
    log_step "Deploying icon PNG fallbacks..."

    if ! command -v rsvg-convert >/dev/null 2>&1; then
        log_warning "rsvg-convert not available; skipping PNG fallback generation"
        return 0
    fi

    local src_dir="/usr/share/icons/hicolor/scalable/apps"
    local dst_root="/usr/share/icons/hicolor"

    local icons=(
        "cachy-update:${src_dir}/cachy-update-blue.svg"
        "cachy-update_updates-available:${src_dir}/cachy-update_updates-available-blue.svg"
    )
    local sizes=(16 22 24 32)

    local did_any=false
    local entry name src size outdir outfile tmp
    for entry in "${icons[@]}"; do
        name="${entry%%:*}"
        src="${entry##*:}"
        [[ -f "$src" ]] || continue

        for size in "${sizes[@]}"; do
            outdir="${dst_root}/${size}x${size}/apps"
            outfile="${outdir}/${name}.png"
            if [[ -e "$outfile" ]]; then
                continue
            fi

            tmp="$(mktemp --suffix=.png "/tmp/${name}-${size}.XXXXXX" 2>/dev/null || mktemp "/tmp/${name}-${size}.XXXXXX")"
            if rsvg-convert -w "$size" -h "$size" "$src" -o "$tmp" >/dev/null 2>&1; then
                _icons_sudo install -Dm644 "$tmp" "$outfile"
                did_any=true
                log_success "Generated PNG: ${size}x${size} ${name}.png"
            fi
            rm -f "$tmp" 2>/dev/null || true
        done
    done

    if [[ "$did_any" == "true" ]]; then
        refresh_icon_cache
        log_success "Icon PNG fallbacks deployed"
    else
        log_info "No icon PNG fallbacks needed"
    fi
}
