# Shell Test Suite

This directory contains Bats (Bash Automated Testing System) tests for the
refactored `openfortivpn-waybar` shell utilities.

## Prerequisites

Bats is vendored under `vendor/`. No system-wide installation is required.

## Running the Tests

From the repository root:

```bash
./tests/shell/vendor/bin/bats tests/shell/openfortivpn-waybar.bats
```

## Test Coverage

The suite covers the pure / stateless functions extracted into
`scripts/utilities/openfortivpn-waybar-lib/`:

- `json_escape` – JSON string escaping
- `config_value` – key lookup from INI-style config files
- `config_or_default` – config lookup with fallback defaults
- `have_cmd` – command existence check
- `build_cmd_string` – shell-quoting of command arguments
