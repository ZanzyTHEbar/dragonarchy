#!/usr/bin/env zsh
#
# misc-utils.zsh - Miscellaneous utility functions
#
# This file contains a collection of functions for miscellaneous utilities.
#

# Get dotfiles root and source logging utilities
# ${0:A:h} resolves symlinks to get the real script location in dotfiles repo
DOTFILES_ROOT="${0:A:h:h:h:h:h:h}"  # Go up 6 levels from packages/zsh/.config/zsh/functions/ to repo root
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${DOTFILES_ROOT}/scripts/lib/logging.sh"

# y shell wrapper that provides the ability to change the current working directory when exiting Yazi.
y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# Prints random height bars across the width of the screen
# (great with lolcat application on new terminal windows)
function random_bars() {
    local columns=$(tput cols)
    local chars=(  ▂ ▃ ▄ ▅ ▆ ▇ █)
    local colors=(31 32 33 34 35 36 37 90 91 92 93 94 95 96)
    for ((i = 1; i <= $columns; i++))
    do
        printf "\e[%sm%s\e[0m" "${colors[RANDOM%${#colors} + 1]}" "${chars[RANDOM%${#chars} + 1]}"
    done
    printf "\n"
}