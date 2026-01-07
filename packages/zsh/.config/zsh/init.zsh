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

# Note: Vi-mode cursor configuration is set in .zshrc after zsh-vi-mode loads

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

# Set up direnv if available
if command -v direnv &> /dev/null; then
    eval "$(direnv hook zsh)"
fi

# Initialize zoxide if available
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# Note: Powerlevel10k is loaded via Zinit in .zshrc
# Fallback prompt only if P10K is not available
if [[ ! -n "$POWERLEVEL9K_MODE" ]]; then
    # Simple custom prompt
    autoload -U colors && colors
    PS1="%{$fg[cyan]%}%n@%m%{$reset_color%}:%{$fg[blue]%}%~%{$reset_color%}$ "
fi

# Initialize completion for various tools
if command -v kubectl &> /dev/null; then
    source <(kubectl completion zsh)
fi

if command -v helm &> /dev/null; then
    source <(helm completion zsh)
fi

# Load additional completions directory if it exists
if [[ -d ~/.config/zsh/completions ]]; then
    fpath=(~/.config/zsh/completions $fpath)
fi 
