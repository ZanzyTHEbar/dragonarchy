# Clear Cursor-injected ARGV0 so argv0-sensitive tools like rustup behave
# normally in Cursor-launched zsh shells without affecting other terminals.
if [[ -n "${ARGV0:-}" ]]; then
  case "${ARGV0##*/}" in
    cursor|cursor.appimage)
      if [[ -n "${CURSOR_AGENT:-}" || -n "${CURSOR_TRACE_ID:-}" || -n "${CURSOR_EXTENSION_HOST_ROLE:-}" || -n "${VSCODE_IPC_HOOK:-}" || "${TERM_PROGRAM:-}" == "Cursor" || "${TERM_PROGRAM:-}" == "vscode" ]]; then
        unset ARGV0
      fi
      ;;
  esac
fi

# >>> cursor-installer path >>>
if [ -f "$HOME/.local/share/cursor-installer/shell-path.sh" ]; then
  . "$HOME/.local/share/cursor-installer/shell-path.sh"
fi
# <<< cursor-installer path <<<

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# opencode
export PATH=$HOME/.opencode/bin:$PATH
