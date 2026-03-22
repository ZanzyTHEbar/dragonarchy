#!/usr/bin/env zsh
#
# misc-utils.zsh - Miscellaneous utility functions
#
# This file contains a collection of functions for miscellaneous utilities.
#

# Get dotfiles root and source logging utilities
# ${(%):-%x} resolves to the current sourced file in zsh. Fall back to $0 for
# linting or non-sourced execution contexts.
SOURCE_PATH="${(%):-%x}"
if [[ -z "$SOURCE_PATH" ]]; then
    SOURCE_PATH="$0"
fi
if [[ -n "$SOURCE_PATH" && "$SOURCE_PATH" != -* ]]; then
    DOTFILES_ROOT="${SOURCE_PATH:A:h:h:h:h:h:h}"  # Go up 6 levels from packages/zsh/.config/zsh/functions/ to repo root
fi
if [[ -z "${DOTFILES_ROOT:-}" || ! -f "${DOTFILES_ROOT}/scripts/lib/logging.sh" ]]; then
    DOTFILES_ROOT="${HOME}/dotfiles"
fi
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${DOTFILES_ROOT:-${HOME}/dotfiles}/scripts/lib/logging.sh"

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

#######################################################
# Calendar Functions (Example for specific months)
#######################################################

showcalendarjd() {
    local YEAR=$(date +%Y)
    for monthly in "Jul" "Aug" "Sep" "Oct"; do
        gcal -j -s Mon -K --iso-week-number=yes ${monthly} ${YEAR}
        echo
    done
}

showcalendarjdb() {
    local YEAR=$(date +%Y)
    for monthly in "Jul" "Aug" "Sep" "Oct"; do
        gcal -jb -s Mon -K --iso-week-number=yes ${monthly} ${YEAR}
        echo
    done
}

showcalendarcw() {
    local YEAR=$(date +%Y)
    for monthly in "Jul" "Aug" "Sep" "Oct"; do
        gcal -s Mon -K --iso-week-number=yes ${monthly} ${YEAR}
        echo
    done
}

ops() {
    # Dependency checks
    if ! command -v opencode &> /dev/null; then
        print -u2 $'\e[31m✗ Error: opencode command not found\e[0m'
        return 1
    fi
    if ! command -v jq &> /dev/null; then
        print -u2 $'\e[31m✗ Error: jq is required (for JSON parsing)\e[0m'
        return 1
    fi

    # Usage if no request and nothing piped in
    if [[ $# -eq 0 && -t 0 ]]; then
        print -u2 $'\e[33mUsage:\e[0m ops "your request" [--file file.txt --image img.png ...]'
        return 1
    fi

    # === Argument separation: everything that starts with -/-- goes to opencode, rest is request ===
    # This lets us write natural prompts without quoting the whole thing
    local -a request_parts=() opencode_args=()
    for arg in "$@"; do
        if [[ $arg == -* ]]; then
            opencode_args+=("$arg")
        else
            request_parts+=("$arg")
        fi
    done

    local request="${(j: :)request_parts}"

    # === Piping input support ===
    if ! [[ -t 0 ]]; then
        local input=$(cat)
        request="=== INPUT FROM PIPE ===\n${input}\n\n${request}"
    fi

    # === Build the exact prompt (unchanged core behaviour) ===
    local prompt="Provide a complete zsh script for this request. Output ONLY the raw script.
No explanations, no markdown, no code blocks.
Start directly with a zsh shebang.

Request: $request"

    # === Run opencode with any extra flags you passed (files, images, agents, etc.) ===
    local script
    script=$(opencode run "$prompt" --log-level ERROR --format json "${opencode_args[@]}" \
             | jq -r 'select(.type=="text") | .part.text')

    # === Piping output support ===
    if [[ -t 1 ]]; then
        # Terminal → copy to clipboard + success message (original behaviour)
        print -n "$script" | wl-copy
        print -P "\n%F{green}✓ Script copied to clipboard%f"
    else
        # Being piped or redirected → output raw script only
        print -n "$script"
    fi
}
