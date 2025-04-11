if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Enable colors and change prompt:
autoload -U colors && colors
PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}$%b "

typeset -U PATH path

path_add() {
    case ":$PATH:" in
        *":$1:"*) :;; # already there
        *) export PATH="$1:$PATH";;
    esac
}

#path+=(
#  "${HOME}/.local/bin"
#  "${GOPATH}/bin"
#  "${GOROOT}/bin"
#)

export GOPATH="$HOME/go"
path_add "$GOPATH/bin"

# NFS MNT
path_add "/mnt/dragonnet/common/bin"

# Add custom paths
path_add "$HOME/.cargo/bin"
path_add "$HOME/.local/bin"
path_add "$HOME/bin"
path_add "/usr/local/bin"
path_add "/usr/local/go/bin"

export RUST_LOG="solana_runtime::system_instruction_processor=trace,solana_runtime::message_processor=debug,solana_bpf_loader=debug,solana_rbpf=debug"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Rust
. "$HOME/.cargo/env"

# eza
export FPATH="$ZSH_CUSTOM/completions/eza:$FPATH"

# To customize prompt, run `p10k configure`or edit the file
[[ ! -f $HOME/.p10k.zsh ]] || source $HOME/.p10k.zsh

POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
CASE_SENSITIVE="true"
ENABLE_CORRECTION="false"
COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"

plugins=(
	git
	nvm
	docker
	npm
	zsh-autosuggestions 
	zsh-syntax-highlighting 
	autojump 
)

source $ZSH/oh-my-zsh.sh

HISTSIZE=10000
SAVEHIST=10000
#HISTFILE=~/.cache/zshhistory
setopt appendhistory

# Basic auto/tab complete:
autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)               # Include hidden files.

# Custom ZSH Binds
bindkey '^ ' autosuggest-accept


[ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

eval "$(pyenv virtualenv-init -)"

export LS_COLORS=$(echo $LS_COLORS | sed "s/ow=34/ow=37;40/")
eval "$(gh copilot alias -- zsh)"

# Load - should be last.
source $HOME/.config/icons-in-terminal/icons_bash.sh