#!/usr/bin/env bash
#
# stow-helpers.sh - Stow conflict resolution and fresh-mode purge helpers
#
# Provides functions to detect and resolve GNU Stow conflicts,
# back up conflicting targets, and purge them before (re)stowing.
#
# Usage: source "${SCRIPT_DIR}/scripts/lib/stow-helpers.sh"
#
# Requires: logging.sh (log_info, log_warning, log_error)

# Fresh-machine helper: backup and remove a path under $HOME (files, symlinks, or directories)
fresh_backup_and_remove() {
    local abs_path="$1"
    local backup_root="$2"
    local package="$3"

    if [[ -z "${abs_path:-}" || -z "${backup_root:-}" || -z "${package:-}" ]]; then
        log_error "fresh_backup_and_remove: missing args"
        return 1
    fi

    # Safety checks (never operate outside of $HOME)
    if [[ "$abs_path" == "$HOME" || "$abs_path" == "/" || "$abs_path" != "$HOME/"* ]]; then
        log_error "Fresh mode refusing to remove unsafe path: $abs_path"
        return 1
    fi

    # Determine backup destination path relative to $HOME
    local rel_from_home="${abs_path#${HOME}/}"
    if [[ -z "$rel_from_home" || "$rel_from_home" == "$abs_path" ]]; then
        log_error "Fresh mode refusing to remove (could not derive rel path): $abs_path"
        return 1
    fi

    local backup_path="${backup_root}/${package}/${rel_from_home}"
    mkdir -p "$(dirname "$backup_path")"

    # Backup first, then remove
    if cp -a "$abs_path" "$backup_path" 2>/dev/null; then
        :
    elif cp -aL "$abs_path" "$backup_path" 2>/dev/null; then
        :
    else
        log_error "Fresh mode backup failed; refusing to delete: $abs_path"
        log_error "Intended backup destination: $backup_path"
        return 1
    fi

    rm -rf "$abs_path" || {
        log_error "Failed to remove $abs_path after backup"
        return 1
    }
}

# Purge stow conflicts based on a captured stow output log (from a real stow/restow run).
# This is more reliable than parsing LINK lines because stow can abort before applying anything.
purge_stow_conflicts_from_output() {
    local package="$1"
    local backup_root="$2"
    local output_file="$3"

    if [[ -z "${package:-}" || -z "${backup_root:-}" || -z "${output_file:-}" ]]; then
        log_error "purge_stow_conflicts_from_output: missing args"
        return 1
    fi
    if [[ ! -f "$output_file" ]]; then
        log_error "purge_stow_conflicts_from_output: output file not found: $output_file"
        return 1
    fi

    declare -A targets=()
    local line
    local re_cannot='\\*[[:space:]]+cannot[[:space:]]+stow[[:space:]]+.+[[:space:]]+over[[:space:]]+existing[[:space:]]+target[[:space:]]+([^[:space:]]+)[[:space:]]+since[[:space:]]+'
    local re_not_owned='\\*[[:space:]]+existing[[:space:]]+target[[:space:]]+is[[:space:]]+not[[:space:]]+owned[[:space:]]+by[[:space:]]+stow:[[:space:]]+(.+)$'
    local re_diff_pkg='\\*[[:space:]]+existing[[:space:]]+target[[:space:]]+is[[:space:]]+stowed[[:space:]]+to[[:space:]]+a[[:space:]]+different[[:space:]]+package:[[:space:]]+([^[:space:]]+)[[:space:]]+=>[[:space:]]+'

    while IFS= read -r line; do
        if [[ "$line" =~ $re_cannot ]]; then
            targets["${BASH_REMATCH[1]}"]=1
            continue
        fi

        if [[ "$line" =~ $re_not_owned ]]; then
            local t="${BASH_REMATCH[1]}"
            t=$(printf '%s' "$t" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            [[ -n "$t" ]] && targets["$t"]=1
            continue
        fi

        if [[ "$line" =~ $re_diff_pkg ]]; then
            targets["${BASH_REMATCH[1]}"]=1
            continue
        fi
    done < "$output_file"

    local removed_count=0
    local t
    for t in "${!targets[@]}"; do
        # Basic safety: stow targets are relative to $HOME
        if [[ "$t" == /* || "$t" == *".."* ]]; then
            log_warning "Conflict purge skipping unsafe target: $t"
            continue
        fi

        local dst="$HOME/$t"
        if [[ -e "$dst" || -L "$dst" ]]; then
            fresh_backup_and_remove "$dst" "$backup_root" "$package" || return 1
            removed_count=$((removed_count + 1))
        fi
    done

    if [[ $removed_count -gt 0 ]]; then
        log_warning "Purged $removed_count conflict target(s) for package '$package' (backups: ${backup_root}/${package})"
    fi
}

# Fresh-machine purge: remove conflicting targets that would block stow for a given package.
# Uses `stow -n -v` to discover intended links (respects stow ignore rules).
fresh_purge_stow_conflicts_for_package() {
    local package="$1"
    local backup_root="$2"

    if [[ -z "${package:-}" || -z "${backup_root:-}" ]]; then
        log_error "fresh_purge_stow_conflicts_for_package: missing args"
        return 1
    fi

    if ! command -v stow >/dev/null 2>&1; then
        log_error "Fresh mode requires GNU Stow to be installed"
        return 1
    fi

    local dry_run
    dry_run=$(stow -n -v -t "$HOME" "$package" 2>&1 || true)

    # Track removed paths to avoid double-work (esp. parent dirs)
    declare -A removed_paths=()
    local removed_count=0

    # Prefer parsing LINK lines: `LINK: <target> => <source>`
    local link_re='^[[:space:]]*LINK:[[:space:]]+([^[:space:]]+)[[:space:]]+=>[[:space:]]+(.+)$'
    local had_link_lines=false
    local line
    while IFS= read -r line; do
        if [[ "$line" =~ $link_re ]]; then
            had_link_lines=true

            local target_rel="${BASH_REMATCH[1]}"
            local source_rel="${BASH_REMATCH[2]}"

            # Trim whitespace (stow output can sometimes include trailing spaces)
            target_rel=$(printf '%s' "$target_rel" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            source_rel=$(printf '%s' "$source_rel" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

            # Guard against weird targets
            if [[ "$target_rel" == /* || "$target_rel" == *".."* ]]; then
                log_warning "Fresh mode skipping unexpected stow target: $target_rel"
                continue
            fi

            local dst="$HOME/$target_rel"
            local src_abs=""
            if [[ "$source_rel" == /* ]]; then
                src_abs=$(readlink -f "$source_rel" 2>/dev/null || true)
            else
                src_abs=$(readlink -f "$HOME/$source_rel" 2>/dev/null || true)
            fi

            # Ensure directory prefixes exist as directories (remove any file/symlink that blocks mkdir)
            local target_dir
            target_dir=$(dirname "$target_rel")
            if [[ "$target_dir" != "." && -n "$target_dir" ]]; then
                local cur="$HOME"
                local IFS='/'
                read -ra parts <<< "$target_dir"
                unset IFS
                local part
                for part in "${parts[@]}"; do
                    [[ -z "$part" ]] && continue
                    cur="$cur/$part"
                    if [[ -n "${removed_paths[$cur]:-}" ]]; then
                        continue
                    fi
                    if [[ ( -e "$cur" || -L "$cur" ) && ! -d "$cur" ]]; then
                        fresh_backup_and_remove "$cur" "$backup_root" "$package"
                        removed_paths["$cur"]=1
                        removed_count=$((removed_count + 1))
                    fi
                done
            fi

            # If destination exists but isn't already the exact intended link, back it up and remove it
            if [[ -n "${removed_paths[$dst]:-}" ]]; then
                continue
            fi

            if [[ -L "$dst" ]]; then
                local dst_abs=""
                dst_abs=$(readlink -f "$dst" 2>/dev/null || true)
                if [[ -n "$src_abs" && -n "$dst_abs" && "$src_abs" == "$dst_abs" ]]; then
                    continue
                fi
            fi

            if [[ -e "$dst" || -L "$dst" ]]; then
                fresh_backup_and_remove "$dst" "$backup_root" "$package"
                removed_paths["$dst"]=1
                removed_count=$((removed_count + 1))
            fi
        fi
    done < <(printf '%s\n' "$dry_run")

    # Fallback: if no LINK lines were found (older stow / different output), purge based on package tree
    if [[ "$had_link_lines" != "true" ]]; then
        while IFS= read -r -d '' src; do
            local rel="${src#${package}/}"
            [[ -z "$rel" || "$rel" == "$src" ]] && continue

            # Mirror stow global ignores for marker/docs files
            case "$(basename "$rel")" in
                .package|README|README.md|README.txt)
                    continue
                ;;
            esac

            # Guard against weird rel paths
            if [[ "$rel" == /* || "$rel" == *".."* ]]; then
                log_warning "Fresh mode skipping unexpected package entry: $rel"
                continue
            fi

            local dst="$HOME/$rel"

            # Ensure parent directories are directories
            local rel_dir
            rel_dir=$(dirname "$rel")
            if [[ "$rel_dir" != "." && -n "$rel_dir" ]]; then
                local cur="$HOME"
                local IFS='/'
                read -ra parts <<< "$rel_dir"
                unset IFS
                local part
                for part in "${parts[@]}"; do
                    [[ -z "$part" ]] && continue
                    cur="$cur/$part"
                    if [[ -n "${removed_paths[$cur]:-}" ]]; then
                        continue
                    fi
                    if [[ ( -e "$cur" || -L "$cur" ) && ! -d "$cur" ]]; then
                        fresh_backup_and_remove "$cur" "$backup_root" "$package"
                        removed_paths["$cur"]=1
                        removed_count=$((removed_count + 1))
                    fi
                done
            fi

            if [[ -n "${removed_paths[$dst]:-}" ]]; then
                continue
            fi

            # If destination exists but isn't already linked to this exact source, purge it
            if [[ -L "$dst" ]]; then
                local dst_abs src_abs
                dst_abs=$(readlink -f "$dst" 2>/dev/null || true)
                src_abs=$(readlink -f "$src" 2>/dev/null || true)
                if [[ -n "$dst_abs" && -n "$src_abs" && "$dst_abs" == "$src_abs" ]]; then
                    continue
                fi
            fi

            if [[ -e "$dst" || -L "$dst" ]]; then
                fresh_backup_and_remove "$dst" "$backup_root" "$package"
                removed_paths["$dst"]=1
                removed_count=$((removed_count + 1))
            fi
        done < <(find "$package" -mindepth 1 \( -type f -o -type l \) -print0 2>/dev/null)
    fi

    if [[ $removed_count -gt 0 ]]; then
        log_warning "Fresh mode purged $removed_count existing target(s) for package '$package' (backups: ${backup_root}/${package})"
    fi
}
