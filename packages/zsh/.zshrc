# ZSH Configuration - Modular Setup
# ===================================

# Powerlevel10k instant prompt initialization
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Load core configuration modules FIRST (order matters)
source ~/.config/zsh/profile.zsh         # Platform detection, environment variables, path functions
source ~/.config/zsh/init.zsh           # Shell options, keybindings, completion, FZF

# Zinit plugin manager setup
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in Powerlevel10k
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

# Load function files
for func_file in ~/.config/zsh/functions/*.zsh; do
    [[ -r "$func_file" ]] && source "$func_file"
done

# Load aliases and remaining configuration
for conf_file in ~/.config/zsh/*.zsh; do
    [[ -r "$conf_file" ]] && source "$conf_file"
done

if [[ -f ~/.config/zsh/hosts/$HOSTNAME.zsh ]]; then
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
[[ -f "$HOME/.config/zsh/.p10k.zsh" ]] && source "$HOME/.config/zsh/.p10k.zsh"

# Unalias zi from zinit to avoid conflicts with zoxide zi command
unalias zi 2>/dev/null

# pnpm
export PNPM_HOME="/home/daofficialwizard/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
