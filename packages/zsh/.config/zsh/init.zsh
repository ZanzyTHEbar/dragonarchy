# ZSH Initialization Configuration

# Enable extended globbing
setopt EXTENDED_GLOB
setopt AUTO_CD
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt PATH_DIRS
setopt AUTO_MENU
setopt AUTO_LIST
setopt AUTO_PARAM_SLASH
setopt FLOW_CONTROL
setopt MENU_COMPLETE
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt CORRECT
setopt INTERACTIVE_COMMENTS
setopt MAGIC_EQUAL_SUBST
setopt NONOMATCH
setopt NOTIFY
setopt NUMERIC_GLOB_SORT
setopt PROMPT_SUBST

# History Configuration
HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt APPENDHISTORY
setopt SHAREHISTORY
setopt HIST_IGNORE_SPACE
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS

# ==== Set up completion system ==== #
if [[ "${ZSH_TTY_UI:-false}" == "true" ]]; then
    # Set up key bindings for history search
    autoload -U up-line-or-beginning-search
    autoload -U down-line-or-beginning-search
    zle -N up-line-or-beginning-search
    zle -N down-line-or-beginning-search

    # Keybindings
    bindkey -v  # Enable vi mode
    bindkey "^[[A" history-beginning-search-backward  # search history with up key
    bindkey "^[[B" history-beginning-search-forward   # search history with down key
    bindkey '^ ' autosuggest-accept
    # bindkey '^p' history-search-backward
    # bindkey '^n' history-search-forward
    # bindkey '^[w' kill-region
    # bindkey ' ' magic-space                         # do history expansion on space

    fpath=(~/.local/share/gh/extensions/gh-branch $fpath)

    autoload -Uz compinit bashcompinit
    bashcompinit
    compinit -i

    # Completion configuration
    zstyle ':completion:*' menu select
    zmodload zsh/complist
    _comp_options+=(globdots)               # Include hidden files.

    # Completion styling
    zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
    zstyle ':completion:*' menu no
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
    zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
    zstyle ':completion:*:*:docker:*' option-stacking yes
    zstyle ':completion:*:*:docker-*:*' option-stacking yes
fi

# Set up direnv if available.
#
# Avoid the default precmd hook because it re-runs `direnv export zsh` before
# every prompt. That gets painful in slow `.envrc` trees (for example Nix-backed
# envs or anything living on NFS/automount paths) and matches the intermittent
# prompt stalls seen on this machine.
#
# `chpwd` still covers the normal case: load/unload envs when entering or
# leaving a project. If `.envrc` changes in-place, `direnv reload` keeps the
# behavior explicit instead of stalling every prompt.
if [[ "${ZSH_TTY_UI:-false}" == "true" ]] && command -v direnv &> /dev/null; then
    autoload -Uz add-zsh-hook 2>/dev/null || true

    # Ignore module/cache trees that may vendor their own `.envrc` files.
    # These should never affect the interactive shell.
    typeset -ga _direnv_ignored_path_prefixes
    _direnv_ignored_path_prefixes=(
        "/mnt/common/bin/pkg/mod"
        "${GOMODCACHE:-$HOME/go/pkg/mod}"
        "${CARGO_HOME:-$HOME/.cargo}/registry"
        "$HOME/.local/share/nvim/lazy"
        "$HOME/.local/share/hyprland-plugins"
    )

    _direnv_should_ignore_pwd() {
        emulate -L zsh
        setopt no_unset 2>/dev/null || true

        local cwd="${1:-$PWD}"
        local prefix

        for prefix in "${_direnv_ignored_path_prefixes[@]}"; do
            [[ -n "$prefix" ]] || continue
            case "$cwd/" in
                "${prefix%/}/"*)
                    return 0
                    ;;
            esac
        done

        return 1
    }

    _direnv_chpwd_hook() {
        emulate -L zsh
        setopt no_unset 2>/dev/null || true

        local export_cmd

        trap -- '' SIGINT

        if _direnv_should_ignore_pwd "$PWD"; then
            # Export from `/` so direnv unloads any previously active project
            # env without ever touching ignored cache/module directories.
            export_cmd="$(builtin cd / && direnv export zsh)"
        else
            export_cmd="$(direnv export zsh)"
        fi

        eval "$export_cmd"
        trap - SIGINT
    }

    if (( $+functions[add-zsh-hook] )); then
        add-zsh-hook chpwd _direnv_chpwd_hook
    fi

    _direnv_chpwd_hook
fi

# Initialize zoxide if available
if [[ "${ZSH_TTY_UI:-false}" == "true" ]] && command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# Note: Powerlevel10k is loaded via Zinit in .zshrc
# Fallback prompt only if P10K is not available
if [[ "${ZSH_TTY_UI:-false}" == "true" && -z "${POWERLEVEL9K_MODE:-}" ]]; then
    # Simple custom prompt
    autoload -U colors && colors
    PS1="%{$fg[cyan]%}%n@%m%{$reset_color%}:%{$fg[blue]%}%~%{$reset_color%}$ "
fi

# Initialize completion for various tools
if [[ "${ZSH_TTY_UI:-false}" == "true" ]] && command -v kubectl &> /dev/null; then
    source <(kubectl completion zsh)
fi

if [[ "${ZSH_TTY_UI:-false}" == "true" ]] && command -v helm &> /dev/null; then
    source <(helm completion zsh)
fi

# Load additional completions directory if it exists
if [[ "${ZSH_TTY_UI:-false}" == "true" && -d ~/.config/zsh/completions ]]; then
    fpath=(~/.config/zsh/completions $fpath)
fi 
