# rm-bg.zsh - Background removal with path hardening
#
# Usage: rm_bg [-h] [--] <path> [path ...]
#   RM_BG_NOTIFY=0        suppress desktop notification
#   RM_BG_SYNC=1          wait for rm and return its status
#   RM_BG_IONICE=1        wrap rm in ionice -c 3 (can stall forever on NFS)
#
# Files, directories, and symlinks are all valid targets.
# Unlink requires write+exec on the parent, not write on the target.
# Privileged deletion is unsupported: a pkexec path cannot be made
# race-resistant from the shell.
# No tombstones, no named log file.
# Protected prefixes are refused regardless of caller.

(( $+functions[log_error] ))   || log_error()   { print -u2 -- "[ERROR] $*"; }
(( $+functions[log_info] ))    || log_info()    { print -- "[INFO] $*"; }
(( $+functions[log_success] )) || log_success() { print -- "[SUCCESS] $*"; }

typeset -gA _RM_BG_CMD_CACHE
typeset -g  _RM_BG_RM_FLAGS_READY=0
typeset -ga _RM_BG_RM_FLAGS

_rm_bg_has() {
    emulate -L zsh
    local name=$1
    if (( ${+_RM_BG_CMD_CACHE[$name]} )); then
        (( _RM_BG_CMD_CACHE[$name] ))
        return $?
    fi
    if (( $+commands[$name] )); then
        _RM_BG_CMD_CACHE[$name]=1
        return 0
    fi
    _RM_BG_CMD_CACHE[$name]=0
    return 1
}

_rm_bg_init_rm_flags() {
    emulate -L zsh
    (( _RM_BG_RM_FLAGS_READY )) && return 0
    _RM_BG_RM_FLAGS=(-rf --)
    local help
    help=$(command rm --help 2>/dev/null) || help=
    [[ $help == *--preserve-root=all* ]] && _RM_BG_RM_FLAGS=(-rf --preserve-root=all --)
    _RM_BG_RM_FLAGS_READY=1
}

_rm_bg_is_protected() {
    emulate -L zsh
    local p=$1
    local home=${HOME:-}
    [[ -n $home ]] && home=${home:A}

    case $p in
        /|/bin|/sbin|/usr|/usr/bin|/usr/sbin|/usr/lib|/usr/lib64 \
        |/lib|/lib64|/etc|/boot|/dev|/proc|/sys|/run|/root \
        |/var|/var/log|/var/lib \
        |/System|/Library|/Applications)
            return 0
            ;;
    esac

    local prefix
    for prefix in /bin /sbin /usr /lib /lib64 /etc /boot /dev /proc /sys /run /root \
                  /var /System /Library /Applications; do
        [[ $p == $prefix/* ]] && return 0
    done

    if [[ -n $home ]]; then
        case $p in
            $home|$home/.ssh|$home/.ssh/*|$home/.gnupg|$home/.gnupg/*)
                return 0
                ;;
        esac
    fi
    return 1
}

_rm_bg_notify() {
    emulate -L zsh
    [[ ${RM_BG_NOTIFY:-1} == 0 ]] && return 0
    local title=$1 body=$2 urgency=${3:-normal}

    if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} && -n ${UID:-} && -S /run/user/${UID}/bus ]]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${UID}/bus"
    fi

    local ns=${commands[notify-send]:-/usr/bin/notify-send}
    if [[ -x $ns ]]; then
        "$ns" --app-name=rm_bg --urgency="$urgency" -- "$title" "$body"
        return 0
    fi

    local gd=${commands[gdbus]:-/usr/bin/gdbus}
    if [[ -x $gd ]]; then
        "$gd" call --session \
            --dest org.freedesktop.Notifications \
            --object-path /org/freedesktop/Notifications \
            --method org.freedesktop.Notifications.Notify \
            rm_bg 0 dialog-warning "$title" "$body" \
            '[]' '{}' 4000 >/dev/null 2>&1
        return 0
    fi

    local bc=${commands[busctl]:-/usr/bin/busctl}
    if [[ -x $bc ]]; then
        "$bc" --user call \
            org.freedesktop.Notifications \
            /org/freedesktop/Notifications \
            org.freedesktop.Notifications Notify \
            susssasa{sv}i \
            rm_bg 0 dialog-warning "$title" "$body" \
            0 0 4000 >/dev/null 2>&1
    fi
}

_rm_bg_usage() {
    print -u2 -- "Usage: rm_bg [-h] [--] <path> [path ...]"
    print -u2 -- "  Remove files, directories, or symlinks in the background."
    print -u2 -- "  -h, --help     show this help"
    print -u2 -- "  --             treat remaining args as paths"
    print -u2 -- "  RM_BG_SYNC=1   wait for rm and return its status"
    print -u2 -- "  RM_BG_NOTIFY=0 suppress desktop notifications"
}

# $1 = summary, $2.. = argv. Keep session fds so notify-send and rm errors work.
_rm_bg_exec() {
    emulate -L zsh
    local summary=$1
    shift
    "$@"
    local rc=$?
    if (( rc == 0 )); then
        _rm_bg_notify "Removed" "$summary" low
    else
        print -u2 -- "rm_bg: remove failed: $summary (rc=$rc)"
        _rm_bg_notify "Remove failed" "$summary (rc=$rc)" critical
    fi
    return $rc
}

rm_bg() {
    emulate -L zsh
    setopt localoptions extendedglob no_notify no_monitor

    local -a args targets
    args=("$@")

    while (( ${#args} )); do
        case ${args[1]} in
            -h|--help)
                _rm_bg_usage
                return 0
                ;;
            --)
                shift args
                break
                ;;
            -*)
                log_error "rm_bg: unknown option: ${args[1]}"
                _rm_bg_usage
                return 1
                ;;
            *)
                break
                ;;
        esac
        shift args
    done

    if (( ${#args} < 1 )); then
        _rm_bg_usage
        return 1
    fi

    local raw abs resolved parent parent_resolved
    local failed=0

    for raw in "${args[@]}"; do
        if [[ -z $raw ]]; then
            log_error "rm_bg: refuse empty path"
            failed=1
            continue
        fi

        case $raw in
            -*)
                log_error "rm_bg: refuse option-like path: $raw (pass as: rm_bg -- $raw)"
                failed=1
                continue
                ;;
            .|./|..|../)
                log_error "rm_bg: refuse relative path '$raw'"
                failed=1
                continue
                ;;
            */.|*/..|*/./*|*/../*)
                log_error "rm_bg: refuse path with . or .. component: $raw"
                failed=1
                continue
                ;;
        esac

        abs=${raw:a}
        resolved=${raw:A}

        if [[ -z $abs || $abs == / || -z $resolved || $resolved == / ]]; then
            log_error "rm_bg: refuse empty or root path: $raw"
            failed=1
            continue
        fi
        if [[ ! -e $abs && ! -L $abs ]]; then
            log_error "rm_bg: no such path: $raw"
            failed=1
            continue
        fi
        if _rm_bg_is_protected "$abs" || _rm_bg_is_protected "$resolved"; then
            log_error "rm_bg: protected path refused: $raw -> $resolved"
            failed=1
            continue
        fi

        parent=${abs:h}
        parent_resolved=${parent:A}
        if [[ $parent_resolved != ${parent:a} ]]; then
            log_error "rm_bg: refuse path through symlinked parent: $raw"
            failed=1
            continue
        fi
        if [[ ! -w $parent || ! -x $parent ]]; then
            log_error "rm_bg: no permission to unlink $raw (parent is not writable/executable)"
            failed=1
            continue
        fi

        targets+=("$abs")
    done

    if (( failed )); then
        log_error "rm_bg: aborted; no paths removed"
        return 1
    fi
    if (( ${#targets} == 0 )); then
        _rm_bg_usage
        return 1
    fi

    local summary
    if (( ${#targets} <= 3 )); then
        summary=${(j:, :)targets}
    else
        summary="${#targets} paths"
    fi

    _rm_bg_init_rm_flags

    # Always use the binary. Interactive `alias rm='rm -iv'` must not apply.
    local rm_bin=${commands[rm]:-/bin/rm}
    local -a cmd
    cmd=()
    if [[ ${RM_BG_IONICE:-0} == 1 ]] && _rm_bg_has ionice; then
        cmd+=(ionice -c 3)
    fi
    _rm_bg_has nice && cmd+=(nice -n 19)
    cmd+=("$rm_bin" "${_RM_BG_RM_FLAGS[@]}" "${targets[@]}")

    _rm_bg_notify "Removing" "$summary" low

    local jobpid rc
    if [[ ${RM_BG_SYNC:-0} == 1 ]]; then
        _rm_bg_exec "$summary" "${cmd[@]}"
        rc=$?
        if (( rc == 0 )); then
            log_success "rm_bg: removed $summary"
        else
            log_error "rm_bg: remove failed $summary (rc=$rc)"
        fi
        return $rc
    fi

    _rm_bg_exec "$summary" "${cmd[@]}" &!
    jobpid=$!
    log_info "rm_bg: removing $summary in background (pid $jobpid)"
    return 0
}
