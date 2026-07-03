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
    for candidate in "$HOME/.dotfiles-profile/current" "$HOME/dotfiles"; do
        if [[ -f "$candidate/scripts/lib/logging.sh" ]]; then
            DOTFILES_ROOT="$candidate"
            break
        fi
    done
fi
if [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/logging.sh" ]]; then
    # shellcheck disable=SC1091  # Runtime-resolved path to logging library
    source "$DOTFILES_ROOT/scripts/lib/logging.sh"
else
    log_error() { print -u2 -- "[ERROR] $*"; }
    log_info() { print -- "[INFO] $*"; }
    log_success() { print -- "[SUCCESS] $*"; }
fi

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
  if ! command -v opencode &> /dev/null; then
    print -u2 $'\e[31m✗ Error: opencode command not found\e[0m'
    return 1
  fi
  if ! command -v jq &> /dev/null; then
    print -u2 $'\e[31m✗ Error: jq is required (for JSON parsing)\e[0m'
    return 1
  fi

  if [[ $# -eq 0 && -t 0 ]]; then
    print -u2 $'\e[33mUsage:\e[0m ops "your request" [--file file.txt --image img.png ...]'
    return 1
  fi

  local -a request_parts=() opencode_args=()
  for arg in "$@"; do
    if [[ $arg == -* ]]; then
      opencode_args+=("$arg")
    else
      request_parts+=("$arg")
    fi
  done

  local request="${(j: :)request_parts}"

  if ! [[ -t 0 ]]; then
    local input=$(cat)
    request="=== INPUT FROM PIPE ===\n${input}\n\n${request}"
  fi

  # Lighter prompt — tool restrictions are now enforced by the agent itself
  local prompt="Provide a complete zsh script for this request.

Rules:
- Output ONLY the raw script.
- Start directly with a proper shebang.
- No explanations, no markdown, no code fences.

Request: $request"

  local script
  script=$(opencode run "$prompt" \
    --log-level ERROR \
    --format json \
    --agent ask \
    "${opencode_args[@]}" \
    | jq -r 'if .type == "text" then .part.text elif .type == "error" then "opencode error: \(.error.data.message // .error.message // .error.name // "unknown error")" | halt_error(1) else empty end')

  if [[ -z "$script" || "$script" =~ ^[[:space:]]*$ ]]; then
    print -u2 $'\e[31m✗ Error: No script content captured from opencode\e[0m'
    return 1
  fi

  if [[ -t 1 ]]; then
    print -n "$script" | wl-copy
    print -P "\n%F{green}✓ Script copied to clipboard%f"
  else
    print -n "$script"
  fi
}

dotview() {
  emulate -L zsh
  local input="$1"
  local format="${2:-png}"          # default PNG; pass svg/pdf/etc as 2nd arg
  local base="${input:t:r}"         # basename without extension
  local tmpout="/tmp/${base}.${format}"

  if [[ -z "$input" || ! -f "$input" ]]; then
    print -u2 "Usage: dotview <file.dot> [format]"
    print -u2 "   e.g. dotview graph.dot          # → PNG"
    print -u2 "        dotview graph.dot svg      # → SVG"
    return 1
  fi

  # Render to /tmp (clean artifact location, never pollutes cwd)
  dot -T"$format" "$input" -o "$tmpout" || return 1

  # Open with whatever you registered (feh / imv / …)
  xdg-open "$tmpout"

  # Optional: echo the temp path for scripting/debug
  print "Rendered → $tmpout"
}
