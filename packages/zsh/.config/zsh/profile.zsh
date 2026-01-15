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
export BROWSER=vivaldi-stable
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

# fnm
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
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
