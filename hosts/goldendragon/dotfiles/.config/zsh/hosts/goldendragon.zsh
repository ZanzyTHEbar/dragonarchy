# Host opt-in: shared NFS-safe tooling (/mnt/common)

if [[ -r "$HOME/.config/zsh/hosts/shared/nfs-common.zsh" ]]; then
    source "$HOME/.config/zsh/hosts/shared/nfs-common.zsh"
fi

export MEMORY_BANK_ROOT="$HOME/Documents/.memory/memory-bank/"

# dirtime - directory time tracker (XDG isolated)
[[ -f "$HOME/.config/dirtime/hook.zsh" ]] && source "$HOME/.config/dirtime/hook.zsh"

