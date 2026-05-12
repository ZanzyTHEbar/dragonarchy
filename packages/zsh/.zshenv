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

export LD_LIBRARY_PATH=/opt/SEGGER/JLink:$LD_LIBRARY_PATH

export PATH=$LD_LIBRARY_PATH:$PATH

# Master toggle (enables many experiments at once)
export OPENCODE_EXPERIMENTAL=1

# Specific high-value undocumented / experimental features
export OPENCODE_EXPERIMENTAL_WORKSPACES=true          # Git worktrees as isolated workspaces
export OPENCODE_EXPERIMENTAL_HTTPAPI=true             # Experimental HTTP API routes (workspaces + more)
export OPENCODE_EXPERIMENTAL_SMART_RULES=true         # Context-aware instruction injection
export OPENCODE_EXPERIMENTAL_BASH_BACKGROUND=true     # Background / non-blocking long bash commands (if available in your build)
export OPENCODE_EXPERIMENTAL_LSP=true                 # LSP Support
export OPENCODE_EXPERIMENTAL_PLAN_MODE=true           # Enhanced plan mode behavior
export OPENCODE_EXPERIMENTAL_FILEWATCHER=true         # Full directory file watching
