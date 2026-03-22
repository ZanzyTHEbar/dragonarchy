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
