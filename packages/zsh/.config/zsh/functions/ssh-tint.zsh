# Theme-aware Kitty tab accent for authenticated SSH sessions.
typeset -g _SSH_TINT_SOURCE="${${(%):-%x}:A}"

_ssh_tint_slot() {
    local fingerprint="$1" encoded first
    local -a alphabet
    alphabet=( {A..Z} {a..z} {0..9} + / )

    [[ "$fingerprint" == SHA256:* ]] || return 1
    encoded="${fingerprint#SHA256:}"
    [[ ${#encoded} -eq 43 && "$encoded" != *[^A-Za-z0-9+/]* ]] || return 1
    first="${encoded[1]}"
    local index=${alphabet[(ie)$first]}
    (( index > 0 )) || return 1
    # ponytail: a 5-bit bucket gives 32 stable colors; fingerprint collisions are accepted.
    print -r -- "$(((index - 1) >> 1))"
}

_ssh_tint_fingerprint_from_log() {
    local log_file="$1" authenticated fingerprints muxed
    [[ -r "$log_file" ]] || return 1
    authenticated="$(command awk '
        {
            sub(/\r$/, "", $0)
            if (($1 == "Authenticated" && $2 == "to") ||
                ($1 == "debug1:" && $2 == "Authenticated" && $3 == "to")) authenticated = 1
        }
        END { print authenticated + 0 }
    ' "$log_file")"
    fingerprints="$(command awk '
        {
            sub(/\r$/, "", $0)
            if ($1 == "debug1:" && $2 == "Server" && $3 == "host" && $4 == "key:") {
                for (i = 5; i <= NF; i++) if ($i ~ /^SHA256:/) print $i
            }
        }
    ' "$log_file")"
    if [[ -n "$fingerprints" ]]; then
        [[ "$authenticated" == 1 ]] || return 1
        local -a unique_fingerprints
        unique_fingerprints=("${(@f)$(print -r -- "$fingerprints" | command awk '!seen[$0]++')}")
        (( ${#unique_fingerprints} == 1 )) || return 1
        _ssh_tint_slot "${unique_fingerprints[1]}" >/dev/null || return 1
        print -r -- "${unique_fingerprints[1]}"
        return 0
    fi

    muxed="$(command awk '
        {
            sub(/\r$/, "", $0)
            if (index($0, "auto-mux: Trying existing master")) tried = 1
            if (index($0, "mux_client_request_session: master session id:")) opened = 1
        }
        END { print (tried && opened) + 0 }
    ' "$log_file")"
    [[ "$muxed" == 1 ]] || return 1
    print -r -- SSH_TINT_REUSED_MASTER
}

_ssh_tint_cache_key() {
    command python3 - "$@" <<'PY'
import hashlib
import sys

print(hashlib.sha256("\0".join(sys.argv[1:]).encode()).hexdigest())
PY
}

_ssh_tint_cache_read() {
    local cache_file="$1" fingerprint
    [[ -f "$cache_file" && ! -L "$cache_file" && -r "$cache_file" ]] || return 1
    fingerprint="$(<"$cache_file")"
    _ssh_tint_slot "$fingerprint" >/dev/null || return 1
    print -r -- "$fingerprint"
}

_ssh_tint_cache_store() {
    local cache_file="$1" fingerprint="$2" cache_dir temporary_file
    _ssh_tint_slot "$fingerprint" >/dev/null || return 1
    cache_dir="${cache_file:h}"
    command mkdir -p "$cache_dir" || return 1
    [[ -d "$cache_dir" && ! -L "$cache_dir" ]] || return 1
    command chmod 700 "$cache_dir" || return 1
    temporary_file="$(command mktemp "$cache_dir/.ssh-tint.XXXXXXXX")" || return 1
    print -r -- "$fingerprint" >"$temporary_file" || {
        command rm -f "$temporary_file"
        return 1
    }
    command chmod 600 "$temporary_file" || {
        command rm -f "$temporary_file"
        return 1
    }
    command mv -f "$temporary_file" "$cache_file" || {
        command rm -f "$temporary_file"
        return 1
    }
}

_ssh_tint_colors() {
    local accent="$1" slot="$2"
    [[ "$accent" =~ '^#[0-9a-fA-F]{6}$' ]] || return 1
    (( slot >= 0 && slot < 32 )) || return 1

    command python3 - "$accent" "$slot" <<'PY'
import colorsys
import sys

accent = sys.argv[1][1:]
slot = int(sys.argv[2])
r, g, b = (int(accent[i:i + 2], 16) / 255 for i in (0, 2, 4))
hue, saturation, value = colorsys.rgb_to_hsv(r, g, b)
r, g, b = colorsys.hsv_to_rgb((hue + slot / 32) % 1, saturation, value)
rgb = tuple(round(component * 255) for component in (r, g, b))
linear = [component / 12.92 if component / 255 <= 0.04045 else ((component / 255 + 0.055) / 1.055) ** 2.4 for component in rgb]
luminance = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
black_contrast = (luminance + 0.05) / 0.05
white_contrast = 1.05 / (luminance + 0.05)
foreground = "#000000" if black_contrast >= white_contrast else "#ffffff"
print("#%02x%02x%02x %s" % (*rgb, foreground))
PY
}

_ssh_tint_apply() {
    local log_file="$1" window_id="$2" cache_file="$3"
    local fingerprint_record fingerprint slot theme_file accent colors tint foreground kitty_socket
    [[ "$window_id" == <-> ]] || return 1
    kitty_socket="${KITTY_LISTEN_ON:-}"
    [[ -n "$kitty_socket" ]] || return 1
    fingerprint_record="$(_ssh_tint_fingerprint_from_log "$log_file")" || return 1
    if [[ "$fingerprint_record" == SSH_TINT_REUSED_MASTER ]]; then
        fingerprint="$(_ssh_tint_cache_read "$cache_file")" || return 1
    else
        fingerprint="$fingerprint_record"
        _ssh_tint_cache_store "$cache_file" "$fingerprint" >/dev/null 2>&1 || true
    fi
    [[ "$fingerprint" == SHA256:* ]] || return 1
    slot="$(_ssh_tint_slot "$fingerprint")" || return 1
    theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/current/theme/kitty.conf"
    [[ -r "$theme_file" ]] || return 1
    accent="$(command awk '$1 == "active_border_color" { print $2; exit }' "$theme_file")"
    [[ "$accent" =~ '^#[0-9a-fA-F]{6}$' ]] || return 1
    colors="$(_ssh_tint_colors "$accent" "$slot")" || return 1
    read -r tint foreground <<<"$colors"
    [[ -n "$tint" && -n "$foreground" ]] || return 1

    command kitty @ --to "$kitty_socket" set-tab-color --match "window_id:$window_id" \
        active_bg="$tint" active_fg="$foreground" \
        inactive_bg="$tint" inactive_fg="$foreground" >/dev/null 2>&1 || return 1
    print -r -- 'SSH_TINT_APPLIED' >>"$log_file"
}

_ssh_tint_watch() {
    local log_file="$1" window_id="$2" cache_file="$3" record
    while ! command awk '$0 == "SSH_TINT_DONE" { done = 1 } END { exit !done }' "$log_file" 2>/dev/null; do
        if command awk '$0 == "SSH_TINT_APPLIED" { applied = 1 } END { exit !applied }' "$log_file" 2>/dev/null; then
            return 0
        fi
        record="$(_ssh_tint_fingerprint_from_log "$log_file" 2>/dev/null)" || record=""
        if [[ "$record" == SSH_TINT_REUSED_MASTER ]]; then
            if _ssh_tint_cache_read "$cache_file" >/dev/null 2>&1; then
                _ssh_tint_apply "$log_file" "$window_id" "$cache_file" >/dev/null 2>&1 && return 0
            fi
        elif [[ "$record" == SHA256:* ]]; then
            _ssh_tint_apply "$log_file" "$window_id" "$cache_file" >/dev/null 2>&1 && return 0
        fi
        command sleep 0.05
    done
}

(( $+aliases[ssh] )) && unalias ssh

ssh() {
    if [[ "$TERM" != xterm-kitty || "${KITTY_WINDOW_ID:-}" != <-> || -n ${SSH_CONNECTION:-} || -n ${SSH_TTY:-} ]]; then
        command ssh "$@"
        return $?
    fi

    # Leave SSH queries, explicit log files, and proxy routes alone.
    local arg skip_next=0 config_output line proxyjump=none proxycommand=none
    local hostname= remote_user= port=22 cache_key cache_file
    local -l loglevel=info
    for arg in "$@"; do
        if (( skip_next )); then
            skip_next=0
            continue
        fi
        case "$arg" in
            -E|-E*|-f*|-q*|-Q*|-G|-V)
                command kitty +kitten ssh "$@"
                return $?
                ;;
            -o) skip_next=1 ;;
            -oProxyJump=*|-oProxyCommand=*)
                command kitty +kitten ssh "$@"
                return $?
                ;;
        esac
    done

    config_output="$(command ssh -G "$@" 2>/dev/null)" || {
        command kitty +kitten ssh "$@"
        return $?
    }
    for line in ${(f)config_output}; do
        case "$line" in
            proxyjump\ *) proxyjump="${line#proxyjump }" ;;
            proxycommand\ *) proxycommand="${line#proxycommand }" ;;
            loglevel\ *) loglevel="${line#loglevel }" ;;
            hostname\ *) hostname="${line#hostname }" ;;
            user\ *) remote_user="${line#user }" ;;
            port\ *) port="${line#port }" ;;
        esac
    done
    if [[ "$proxyjump" != none || "$proxycommand" != none || "$loglevel" != info ]]; then
        command kitty +kitten ssh "$@"
        return $?
    fi
    [[ -n "$hostname" && -n "$remote_user" && "$port" == <-> ]] || {
        command kitty +kitten ssh "$@"
        return $?
    }
    cache_key="$(_ssh_tint_cache_key "$hostname" "$remote_user" "$port")" || {
        command kitty +kitten ssh "$@"
        return $?
    }
    [[ ${#cache_key} -eq 64 && "$cache_key" != *[^0-9a-f]* ]] || {
        command kitty +kitten ssh "$@"
        return $?
    }
    cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/ssh-tint/$cache_key"

    local log_file watcher_pid=0 ssh_status=255
    log_file="$(command mktemp "${TMPDIR:-/tmp}/ssh-tint.XXXXXXXX")" || {
        command kitty +kitten ssh "$@"
        return $?
    }
    # Observe the client log for both fresh handshakes and reused ControlMaster sessions.
    setopt localoptions no_errexit no_monitor nonotify
    {
        _ssh_tint_watch "$log_file" "$KITTY_WINDOW_ID" "$cache_file" >/dev/null 2>&1 &
        watcher_pid=$!
        command kitty +kitten ssh -v -E "$log_file" "$@"
        ssh_status=$?
    } always {
        print -r -- 'SSH_TINT_DONE' >>"$log_file"
        if (( watcher_pid > 0 )); then
            command kill "$watcher_pid" 2>/dev/null || true
            wait "$watcher_pid" 2>/dev/null || true
        fi
        if command awk '$0 == "SSH_TINT_APPLIED" { applied = 1 } END { exit !applied }' "$log_file" 2>/dev/null; then
            if [[ -n "${KITTY_LISTEN_ON:-}" ]]; then
                command kitty @ --to "$KITTY_LISTEN_ON" set-tab-color --match "window_id:$KITTY_WINDOW_ID" \
                    active_bg=NONE active_fg=NONE inactive_bg=NONE inactive_fg=NONE >/dev/null 2>&1 || true
            fi
        fi
        command rm -f "$log_file"
    }
    return $ssh_status
}

if [[ "${0:t}" == ssh-tint.zsh && "${1:-}" == --apply ]]; then
    _ssh_tint_apply "${2:-}" "${3:-}" "${4:-}"
    exit $?
fi
