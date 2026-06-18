# Host opt-in: shared NFS-safe tooling (/mnt/common)

if [[ -r "$HOME/.config/zsh/hosts/shared/nfs-common.zsh" ]]; then
    source "$HOME/.config/zsh/hosts/shared/nfs-common.zsh"
fi

export MEMORY_BANK_ROOT="/mnt/dragonnet/.memory/memory-bank/"

export PATH=/home/daofficialwizard/bin:$PATH

[[ -e "/home/daofficialwizard/lib/oracle-cli/lib/python3.14/site-packages/oci_cli/bin/oci_autocomplete.sh" ]] && source "/home/daofficialwizard/lib/oracle-cli/lib/python3.14/site-packages/oci_cli/bin/oci_autocomplete.sh"

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
