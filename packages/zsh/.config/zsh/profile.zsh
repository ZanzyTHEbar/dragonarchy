# ZSH Profile Configuration
# Platform detection
case "$(uname -s)" in
Darwin*)
    export PLATFORM="macos"
    ;;
Linux*)
    export PLATFORM="linux"
    # Detect specific Linux distributions
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        export LINUX_DISTRO="$ID"
    fi
    ;;
*)
    export PLATFORM="unknown"
    ;;
esac

# Host detection
export HOSTNAME="$(hostname | cut -d. -f1)"

# Load platform-specific configurations
case "$PLATFORM" in
"macos")
    # macOS specific exports
    export HOMEBREW_PREFIX="/opt$HOMEbrew"
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"

    # Load Homebrew environment if available
    if [[ -f "$HOMEBREW_PREFIX/bin/brew" ]]; then
        eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
    fi

    # macOS specific aliases
    alias airport='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport'
    alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
    ;;

"linux")
    # Linux specific configurations
    case "$LINUX_DISTRO" in
    "arch" | "cachyos" | "manjaro")
        # Arch-based distributions
        alias pacu='sudo pacman -Syu'
        alias pacs='pacman -Ss'
        alias paci='sudo pacman -S'
        alias pacr='sudo pacman -R'
        alias pacclean='sudo pacman -Sc'
        alias paruu='paru -Syu'
        alias parus='paru -Ss'
        alias parui='paru -S'
        ;;
    "ubuntu" | "debian")
        # Debian-based distributions
        alias aptu='sudo apt update && sudo apt upgrade'
        alias apts='apt search'
        alias apti='sudo apt install'
        alias aptr='sudo apt remove'
        alias aptclean='sudo apt autoremove && sudo apt autoclean'
        ;;
    esac
    ;;
esac

export EDITOR=nvim
export VISUAL=nvim
export SUDO_EDITOR="nvim visudo"
export FCEDIT=nvim
export TERMINAL=kitty
export BROWSER=vivaldi
export PROTON_ENABLE_WAYLAND=1
export CHROME_EXECUTABLE=/usr/bin/vivaldi-stable

if [[ -x "$(command -v bat)" ]]; then
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    export PAGER=bat
fi
export LIBVIRT_DEFAULT_URI="qemu:///system"
export LS_COLORS=$(echo $LS_COLORS | sed "s/ow=34/ow=37;40/")
# Development environment setup
if command -v pyenv &>/dev/null; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
fi

# Node version manager
if [[ -d "$HOME/.nvm" ]]; then
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
fi

# Rust environment
if [[ -f "$HOME/.cargo/env" ]]; then
    source "$HOME/.cargo/env"
fi

# Go environment
if command -v go &>/dev/null; then
    export GOPATH="$HOME/go"
    export PATH="$GOPATH/bin:$PATH"
fi

# Ruby environment
if command -v rbenv &>/dev/null; then
    eval "$(rbenv init -)"
fi

# Java environment
if [[ -n "$JAVA_HOME" ]]; then
    export PATH="$JAVA_HOME/bin:$PATH"
fi

# Path manipulation functions
pathappend() {
    for ARG in "$@"; do
        if [ -d "$ARG" ] && [[ ":$PATH:" != *":$ARG:"* ]]; then
            PATH="${PATH:+"$PATH:"}$ARG"
        fi
    done
}

pathprepend() {
    for ARG in "$@"; do
        if [ -d "$ARG" ] && [[ ":$PATH:" != *":$ARG:"* ]]; then
            PATH="$ARG${PATH:+":$PATH"}"
        fi
    done
}

# Apply PATH configuration using path functions
pathprepend "$HOME/bin" "$HOME/sbin" "$HOME/.local/bin" "$HOME/local/bin" "$HOME/.bin" "$HOME/.local/share/dragon"
pathappend "/usr/local/bin" "/usr/local/go/bin"
pathappend

# Development environment paths
if [[ -n "$GOPATH" ]]; then
    pathappend "$GOPATH/bin"
fi

pathappend "$HOME/.cargo/bin"

# PNPM setup
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac

[ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"
export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"

# Git safe.directory helpers
_git_safe_usage() {
    echo "usage: git_safe [add|remove|list] [-v|--verbose] [--single|--children|--recursive] <path>" 1>&2
}

_git_safe_collect_repos() {
    # args: mode path
    local mode="$1"
    local base="$2"
    case "$mode" in
        single)
            if [ -d "$base/.git" ]; then
                echo "$base"
            fi
            ;;
        children)
            if [ -d "$base" ]; then
                setopt localoptions extendedglob globstarshort null_glob
                local -a _dirs
                local d
                _dirs=( $base/*(N/) )
                for d in "${_dirs[@]}"; do
                    [ -d "$d/.git" ] && printf '%s\n' "$d"
                done
            fi
            ;;
        recursive)
            if [ -d "$base" ]; then
                setopt localoptions extendedglob globstarshort null_glob
                local -a _dirs
                local d
                _dirs=( $base/**/*(N/) )
                for d in "${_dirs[@]}"; do
                    [ -d "$d/.git" ] && printf '%s\n' "$d"
                done
            fi
            ;;
    esac
}

git_safe() {
    local op mode path verbose
    op="$1"; shift || true
    case "$op" in
        add|remove|list) ;;
        *) _git_safe_usage; return 2 ;;
    esac

    mode="single"
    verbose=0
    # parse options
    while :; do
        case "${1-}" in
            --single) mode="single"; shift ;;
            --children) mode="children"; shift ;;
            --recursive) mode="recursive"; shift ;;
            -v|--verbose) verbose=1; shift ;;
            *) break ;;
        esac
    done

    local _log
    _log() { [ "$verbose" -eq 1 ] && echo "git_safe: $*" 1>&2; }

    # Resolve git binary robustly
    local GIT_BIN
    if command -v git >/dev/null 2>&1; then
        GIT_BIN="$(command -v git)"
    elif [ -x /usr/bin/git ]; then
        GIT_BIN="/usr/bin/git"
    elif [ -x /bin/git ]; then
        GIT_BIN="/bin/git"
    else
        echo "git_safe: git not found" 1>&2; return 127
    fi

    if [ "$op" = "list" ]; then
        local entries uentries
        entries=( "${(@f)$("$GIT_BIN" config --file "$HOME/.gitconfig.local" --get-all safe.directory 2>/dev/null)}" )
        typeset -aU uentries
        uentries=( "${entries[@]}" )
        printf "%s\n" "${uentries[@]}"
        return 0
    fi

    path="${1-}"
    if [ -z "$path" ]; then
        _git_safe_usage; return 2
    fi

    _log "op=$op mode=$mode path=$path git=$GIT_BIN"

    # Validate base path
    if [ ! -e "$path" ]; then
        echo "git_safe: path not found: $path" 1>&2; return 1
    fi

    # Ensure local config exists without truncation
    [ -f "$HOME/.gitconfig.local" ] || : > "$HOME/.gitconfig.local"

    # Ensure [safe] section exists before adding entries (only if no safe.* present and no [safe] header)
    if [ "$op" = "add" ]; then
        local _has_safe=0 _names _n
        _names=( "${(@f)$("$GIT_BIN" config --file "$HOME/.gitconfig.local" --name-only --list 2>/dev/null)}" )
        for _n in "${_names[@]}"; do
            [[ "$_n" == safe.* ]] && _has_safe=1 && break
        done
        if (( _has_safe == 0 )); then
            local _line
            while IFS= read -r _line; do
                [[ "$_line" == "[safe]"* ]] && _has_safe=1 && break
            done < "$HOME/.gitconfig.local"
        fi
        if (( _has_safe == 0 )); then
            _log "creating [safe] section"
            printf '%s\n' '[safe]' >> "$HOME/.gitconfig.local"
        fi
    fi

    # Single repo path
    if [ "$mode" = "single" ]; then
        if [ ! -d "$path/.git" ]; then
            echo "git_safe: not a git repo (no .git): $path" 1>&2; return 1
        fi
        local repo="$path" _curr _e _exists
        _curr=( "${(@f)$("$GIT_BIN" config --file "$HOME/.gitconfig.local" --get-all safe.directory 2>/dev/null)}" )
        if [ "$op" = "add" ]; then
            _exists=0
            for _e in "${_curr[@]}"; do
                [[ "$_e" == "$repo" ]] && _exists=1 && break
            done
            if (( _exists == 0 )); then
                _log "adding $repo"
                "$GIT_BIN" config --file "$HOME/.gitconfig.local" --add safe.directory "$repo"
            else
                _log "already present $repo"
            fi
        else
            _log "removing $repo"
            "$GIT_BIN" config --file "$HOME/.gitconfig.local" --unset-all safe.directory "$repo" 2>/dev/null || true
        fi
        return 0
    fi

    # children/recursive enumeration using array to avoid subshell issues
    local repos
    repos=( "${(@f)$(_git_safe_collect_repos "$mode" "$path")}" )
    _log "enumerated repos: ${#repos[@]}"

    local count=0 _curr _e repo
    _curr=( "${(@f)$("$GIT_BIN" config --file "$HOME/.gitconfig.local" --get-all safe.directory 2>/dev/null)}" )
    for repo in "${repos[@]}"; do
        [ -n "$repo" ] || continue
        [ -d "$repo/.git" ] || continue
        if [ "$op" = "add" ]; then
            local _exists=0
            for _e in "${_curr[@]}"; do
                [[ "$_e" == "$repo" ]] && _exists=1 && break
            done
            if (( _exists == 0 )); then
                _log "adding $repo"
                "$GIT_BIN" config --file "$HOME/.gitconfig.local" --add safe.directory "$repo"
            else
                _log "already present $repo"
            fi
        else
            _log "removing $repo"
            "$GIT_BIN" config --file "$HOME/.gitconfig.local" --unset-all safe.directory "$repo" 2>/dev/null || true
        fi
        count=$((count+1))
    done
    _log "processed $count repo(s)"
}

alias git-safe=git_safe
