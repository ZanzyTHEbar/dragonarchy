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

# Set up completion system
autoload -Uz compinit bashcompinit
bashcompinit
compinit

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

# Load FZF if available
# if command -v fzf &> /dev/null; then
#     # Set up FZF key bindings and fuzzy completion
#     if [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
#         source /usr/share/fzf/key-bindings.zsh
#     elif [[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]]; then
#         source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
#     fi
#     
#     if [[ -f /usr/share/fzf/completion.zsh ]]; then
#         source /usr/share/fzf/completion.zsh  
#     elif [[ -f /opt/homebrew/opt/fzf/shell/completion.zsh ]]; then
#         source /opt/homebrew/opt/fzf/shell/completion.zsh
#     fi
#     
#     # Custom FZF configuration
#     export FZF_DEFAULT_OPTS="--info=inline-right --ansi --layout=reverse --border=rounded --color=border:#27a1b9 --color=fg:#c0caf5 --color=gutter:#16161e --color=header:#ff9e64 --color=hl+:#2ac3de --color=hl:#2ac3de --color=info:#545c7e --color=marker:#ff007c --color=pointer:#ff007c --color=prompt:#2ac3de --color=query:#c0caf5:regular --color=scrollbar:#27a1b9 --color=separator:#ff9e64 --color=spinner:#ff007c"
#     
#     # Use fd for file finding if available
#     if command -v fd &> /dev/null; then
#         export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
#         export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
#     fi
# fi

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