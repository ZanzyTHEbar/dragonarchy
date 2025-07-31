# Setup fzf
# ---------
if [[ ! "$PATH" == */usr/bin/fzf* ]]; then
  # Add fzf to path if not already there
  if command -v fzf >/dev/null 2>&1; then
    # FZF is installed via package manager
    export FZF_BASE=$(dirname $(which fzf))
  fi
fi

# Auto-completion and key bindings
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh) 2>/dev/null || true
fi

# Use fd instead of find if available
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

# FZF theme matching Tokyo Night
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
  --info=inline-right \
  --ansi \
  --layout=reverse \
  --border=rounded \
  --color=border:#27a1b9 \
  --color=fg:#c0caf5 \
  --color=gutter:#16161e \
  --color=header:#ff9e64 \
  --color=hl+:#2ac3de \
  --color=hl:#2ac3de \
  --color=info:#545c7e \
  --color=marker:#ff007c \
  --color=pointer:#ff007c \
  --color=prompt:#2ac3de \
  --color=query:#c0caf5:regular \
  --color=scrollbar:#27a1b9 \
  --color=separator:#ff9e64 \
  --color=spinner:#ff007c \
"