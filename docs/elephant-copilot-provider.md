# Elephant Copilot Provider (Walker)

Opt-in Elephant provider that exposes GitHub Copilot CLI in Walker, with
model selection, session support, and command extraction.

## Prereqs

- GitHub Copilot CLI installed (`copilot` or `gh copilot`)
- Go toolchain (to build the provider plugin)

## Install

```bash
elephant-copilot-install
```

This builds the plugin from `~/Documents/elephant-copilot-provider`,
installs it to `~/.config/elephant/providers/`, and writes
`~/.config/elephant/copilot.toml` if missing.

The installer prefers Elephant source from the AUR cache
(`~/.cache/paru/clone/elephant-all/vX.Y.Z.tar.gz`) to avoid Go plugin
version mismatches. If needed, set:

```bash
COPILOT_ELEPHANT_VERSION=2.19.1 elephant-copilot-install
```

Or extract the tarball manually to
`~/Documents/elephant-copilot-provider/third_party/elephant`.

If Elephant logs a provider load error about `internal/goarch`, rebuild
with a matching GOAMD64 value:

```bash
COPILOT_GOAMD64=v3 elephant-copilot-install
```

## Enable

Ensure `~/.config/elephant/copilot.toml` contains:

```toml
enabled = true
```

## Use

- Open Walker and type `~` to enter the Copilot chat.
- Type your message and press `Enter` to send.
- The response streams into the preview side panel (chat transcript file).

### Keybinds

- `ctrl m` → models menu
- `ctrl p` → sessions menu
- `ctrl s` → persist current session
- `ctrl h` → return to chat
- `ctrl r` → rename session (use current query as name)
- `ctrl shift p` → pin/unpin session
- `ctrl c` → copy last answer
- `ctrl shift c` → copy last error
- `ctrl shift t` → copy full transcript
- `ctrl e` → edit transcript
- `ctrl shift e` → apply transcript edits
- `ctrl y` → copy command
- `ctrl shift y` → copy all commands

## Notes

- Temporary sessions are in-memory only; persistent sessions live under
  `XDG_STATE_HOME/elephant/copilot`.
- Command parsing uses fenced code blocks and lines prefixed with `$` or `>`.
  Override via `command_extract_regex` if needed.
