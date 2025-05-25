# Setup fzf
# ---------
if [[ ! "$PATH" == */home/daofficialwizard/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/daofficialwizard/.fzf/bin"
fi

source <(fzf --zsh)
