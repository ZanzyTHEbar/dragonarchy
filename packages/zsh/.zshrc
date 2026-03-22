# ZSH Configuration - Modular Setup
# ===================================

# Startup config intentionally avoids nounset because several third-party Zsh
# plugins and prompt helpers are not nounset-safe during initialization.
unsetopt nounset 2>/dev/null

ZSH_TTY_UI=false
if [[ -o interactive ]]; then
    ZSH_TTY_UI=true
fi

# Powerlevel10k instant prompt initialization
if [[ "$ZSH_TTY_UI" == "true" && -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Load core configuration modules FIRST (order matters)
[[ -r ~/.config/zsh/profile.zsh ]] && source ~/.config/zsh/profile.zsh         # Platform detection, environment variables, path functions
[[ -r ~/.config/zsh/init.zsh ]] && source ~/.config/zsh/init.zsh               # Shell options, keybindings, completion, FZF

# Zinit plugin manager setup
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    if command -v git >/dev/null 2>&1; then
        git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" >/dev/null 2>&1 || true
    fi
fi

# Source/Load zinit
if [[ "$ZSH_TTY_UI" == "true" && -r "${ZINIT_HOME}/zinit.zsh" ]]; then
    source "${ZINIT_HOME}/zinit.zsh"
fi

# Add in Powerlevel10k
if [[ "$ZSH_TTY_UI" == "true" ]] && command -v zinit >/dev/null 2>&1; then
    zinit ice depth=1; zinit light romkatv/powerlevel10k

# Add in zsh plugins
    zinit light zsh-users/zsh-syntax-highlighting
    zinit light zsh-users/zsh-completions
    zinit light zsh-users/zsh-autosuggestions
    zinit light Aloxaf/fzf-tab
    zinit light jeffreytse/zsh-vi-mode
    zinit light zdharma-continuum/fast-syntax-highlighting
    zinit light zdharma-continuum/history-search-multi-word

# Add in snippets
    zinit snippet OMZP::git
    zinit snippet OMZP::sudo
    zinit snippet OMZP::zoxide
    zinit snippet OMZP::direnv
    zinit snippet OMZP::nvm
    zinit snippet OMZP::npm
    zinit snippet OMZP::docker-compose
    zinit snippet OMZP::docker
    zinit snippet OMZP::command-not-found

# Vi-mode cursor configuration (after zsh-vi-mode loads)
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM
ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE

# Replay zinit completions
    zinit cdreplay -q
fi

if [[ "$ZSH_TTY_UI" == "true" ]]; then
    # Load function files
    setopt localoptions nullglob
    for func_file in "$HOME"/.config/zsh/functions/*.zsh; do
        [[ -r "$func_file" ]] && source "$func_file"
    done

    # Load aliases and remaining configuration
    for conf_file in "$HOME"/.config/zsh/*.zsh; do
        case "${conf_file:t}" in
            profile.zsh|init.zsh)
                continue
                ;;
        esac
        [[ -r "$conf_file" ]] && source "$conf_file"
    done
fi

if [[ "$ZSH_TTY_UI" == "true" && -f ~/.config/zsh/hosts/$HOSTNAME.zsh ]]; then
    source ~/.config/zsh/hosts/$HOSTNAME.zsh
fi

# Powerlevel10k configuration
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
ZSH_THEME="powerlevel10k/powerlevel10k"
CASE_SENSITIVE="true"
ENABLE_CORRECTION="false"
COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"

# Load icons
[[ -f "$HOME/.config/icons-in-terminal/icons_bash.sh" ]] && source "$HOME/.config/icons-in-terminal/icons_bash.sh"

# Load .p10k.zsh
if [[ "$ZSH_TTY_UI" == "true" && -f "$HOME/.config/zsh/.p10k.zsh" ]]; then
    source "$HOME/.config/zsh/.p10k.zsh"
fi

# Unalias zi from zinit to avoid conflicts with zoxide zi command
unalias zi 2>/dev/null


# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# >>> cursor-installer path >>>
if [ -f "$HOME/.local/share/cursor-installer/shell-path.sh" ]; then
  . "$HOME/.local/share/cursor-installer/shell-path.sh"
fi
# <<< cursor-installer path <<<