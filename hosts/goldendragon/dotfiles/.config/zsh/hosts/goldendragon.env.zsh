# Host-specific tool paths for non-TTY and TTY interactive shells.

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=("$HOME/.grok/completions/zsh" $fpath)
# <<< grok installer <<<

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
