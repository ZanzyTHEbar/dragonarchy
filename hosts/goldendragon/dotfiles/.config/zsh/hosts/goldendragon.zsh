# Host opt-in: shared NFS-safe tooling (/mnt/common)

if [[ -r "$HOME/.config/zsh/hosts/shared/nfs-common.zsh" ]]; then
    source "$HOME/.config/zsh/hosts/shared/nfs-common.zsh"
fi

export MEMORY_BANK_ROOT="$HOME/Documents/.memory/memory-bank/"

# dirtime - directory time tracker (XDG isolated)
[[ -f "$HOME/.config/dirtime/hook.zsh" ]] && source "$HOME/.config/dirtime/hook.zsh"

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<

# bun completions
[ -s "/home/daofficialwizard/.bun/_bun" ] && source "/home/daofficialwizard/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
