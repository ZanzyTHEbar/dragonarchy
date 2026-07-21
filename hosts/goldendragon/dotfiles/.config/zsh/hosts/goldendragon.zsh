# Host opt-in: shared NFS-safe tooling (/mnt/common)

if [[ -r "$HOME/.config/zsh/hosts/shared/nfs-common.zsh" ]]; then
    source "$HOME/.config/zsh/hosts/shared/nfs-common.zsh"
fi

export MEMORY_BANK_ROOT="$HOME/Documents/.memory/memory-bank/"

# dirtime - directory time tracker (XDG isolated)
[[ -f "$HOME/.config/dirtime/hook.zsh" ]] && source "$HOME/.config/dirtime/hook.zsh"

# bun completions
if [[ "${ZSH_TTY_UI:-false}" == "true" && -s "${BUN_INSTALL:-$HOME/.bun}/_bun" ]]; then
    source "${BUN_INSTALL:-$HOME/.bun}/_bun"
fi
