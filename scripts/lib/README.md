# Scripts Library (lib/)

Centralized utilities and shared functions for all dotfiles scripts.

## Available Libraries

### `logging.sh`

Provides standardized logging functions with color-coded output.

#### Available Functions

- `log_info "message"` - Blue info messages
- `log_success "message"` - Green success messages
- `log_warning "message"` - Yellow warning messages
- `log_error "message"` - Red error messages
- `log_step "message"` - Cyan step/progress messages
- `log_debug "message"` - Purple debug messages (only shown if `DEBUG=1`)
- `log_fatal "message"` - Red fatal error that exits the script

#### Usage in Your Scripts

**Step 1:** Add the source statement at the top of your script (after set flags):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging utilities
source "${SCRIPT_DIR}/path/to/logging.sh"
```

**Step 2:** Adjust the path based on your script's location:

| Script Location | Source Path |
|----------------|-------------|
| `/dotfiles/setup.sh` | `${SCRIPT_DIR}/scripts/lib/logging.sh` |
| `/dotfiles/scripts/*.sh` | `${SCRIPT_DIR}/lib/logging.sh` |
| `/dotfiles/scripts/install/*.sh` | `${SCRIPT_DIR}/../lib/logging.sh` |
| `/dotfiles/scripts/install/setup/*.sh` | `${SCRIPT_DIR}/../../lib/logging.sh` |
| `/dotfiles/scripts/utilities/*.sh` | `${SCRIPT_DIR}/../lib/logging.sh` |
| `/dotfiles/scripts/theme-manager/*.sh` | `${SCRIPT_DIR}/../lib/logging.sh` |

**Step 3:** Remove your local color and logging function definitions:

Delete these sections from your scripts:

```bash
# DELETE THIS:
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# DELETE THIS:
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
# ... etc
```

#### Example: Complete Migration

**Before:**

```bash
#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

main() {
    log_info "Starting..."
    log_error "Something failed"
}

main "$@"
```

**After:**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/logging.sh"  # Adjust path as needed

main() {
    log_info "Starting..."
    log_error "Something failed"
}

main "$@"
```

#### Benefits

✅ **Single source of truth** - Update logging format once, applies everywhere  
✅ **Consistency** - All scripts use identical logging  
✅ **Maintainability** - No duplicate code across 27+ scripts  
✅ **Extensibility** - Easy to add new logging levels or features  
✅ **Testability** - Can mock or redirect logging in one place  

#### Debug Mode

Enable debug logging by setting the `DEBUG` environment variable:

```bash
DEBUG=1 ./your-script.sh
```

### `notifications.sh`

Provides a single helper for sending desktop notifications consistently.

#### Available Functions

- `notify_send [--app name] [--icon name] [--urgency level] [--expire ms] [--timeout duration] [--action key=Label] [--wait] -- "Title" "Body"`

#### Usage

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/notifications.sh"  # Adjust path as needed

notify_send --app "My Script" "Done" "All tasks completed"
```
