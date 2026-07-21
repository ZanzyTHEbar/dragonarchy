# Host opt-in: shared NFS-safe tooling (/mnt/common)

if [[ -r "$HOME/.config/zsh/hosts/shared/nfs-common.zsh" ]]; then
    source "$HOME/.config/zsh/hosts/shared/nfs-common.zsh"
fi

export MEMORY_BANK_ROOT="/mnt/dragonnet/.memory/memory-bank/"

export PATH=/home/daofficialwizard/bin:$PATH

[[ -e "/home/daofficialwizard/lib/oracle-cli/lib/python3.14/site-packages/oci_cli/bin/oci_autocomplete.sh" ]] && source "/home/daofficialwizard/lib/oracle-cli/lib/python3.14/site-packages/oci_cli/bin/oci_autocomplete.sh"

# bun completions
if [[ "${ZSH_TTY_UI:-false}" == "true" && -s "${BUN_INSTALL:-$HOME/.bun}/_bun" ]]; then
    source "${BUN_INSTALL:-$HOME/.bun}/_bun"
fi
