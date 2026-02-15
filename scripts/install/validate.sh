#!/usr/bin/env bash

# System Validation Script
# Validates the dotfiles setup and system health

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../lib/logging.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/hosts.sh"

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# JSON output mode
JSON_OUTPUT=false
# Override host for validation (empty = auto-detect)
VALIDATE_HOST=""
# Structured results (for JSON mode)
declare -a JSON_RESULTS=()

# Wrapper functions that log AND increment counters
check_pass() {
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        JSON_RESULTS+=("{\"status\":\"pass\",\"message\":$(printf '%s' "$*" | jq -Rs .)}")
    else
        log_success "$@"
    fi
}

check_fail() {
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        JSON_RESULTS+=("{\"status\":\"fail\",\"message\":$(printf '%s' "$*" | jq -Rs .)}")
    else
        log_error "$@"
    fi
}

check_warn() {
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        JSON_RESULTS+=("{\"status\":\"warn\",\"message\":$(printf '%s' "$*" | jq -Rs .)}")
    else
        log_warning "$@"
    fi
}

# Check essential commands
check_essential_commands() {
    log_info "Checking essential commands..."
    
    local essential_commands=(
        "zsh"
        "git"
        "stow"
        "curl"
        "grep"
        "sed"
        "awk"
        "jq"
    )
    
    for cmd in "${essential_commands[@]}"; do
        if command_exists "$cmd"; then
            check_pass "$cmd is available"
        else
            check_fail "$cmd is missing"
        fi
    done
}

# Check modern CLI tools
check_modern_tools() {
    log_info "Checking modern CLI tools..."
    
    local modern_tools=(
        "nvim"
        "bat"
        "lsd"
        "fzf"
        "ripgrep"
        "fd"
        "zoxide"
        "direnv"
        "age"
        "sops"
    )
    
    for tool in "${modern_tools[@]}"; do
        if command_exists "$tool"; then
            check_pass "$tool is available"
        else
            check_warn "$tool is missing (optional but recommended)"
        fi
    done
}

# Check dotfiles installation
check_dotfiles() {
    log_info "Checking dotfiles installation..."
    
    local dotfiles=(
        "$HOME/.zshrc"
        "$HOME/.gitconfig" 
        "$HOME/.config/kitty/kitty.conf"
        "$HOME/.config/zsh/aliases.zsh"
        "$HOME/.config/functions/git-utils.zsh"
        "$HOME/.ssh/config"
    )
    
    for file in "${dotfiles[@]}"; do
        if [[ -f "$file" ]]; then
            check_pass "$file exists"
        elif [[ -L "$file" ]]; then
            if [[ -e "$file" ]]; then
                check_pass "$file exists (symlink)"
            else
                check_fail "$file is a broken symlink"
            fi
        else
            check_fail "$file is missing"
        fi
    done
}

# Check shell configuration
check_shell_config() {
    log_info "Checking shell configuration..."
    
    # Check default shell
    if [[ "$SHELL" == */zsh ]]; then
        check_pass "Default shell is zsh"
    else
        check_warn "Default shell is not zsh: $SHELL"
    fi
    
    # Check if zsh configuration loads without errors
    if zsh -c 'source ~/.zshrc' 2>/dev/null; then
        check_pass "Zsh configuration loads without errors"
    else
        check_fail "Zsh configuration has errors"
    fi
    
    # Check environment variables
    local important_vars=(
        "EDITOR"
        "PATH"
        "HOME"
    )
    
    for var in "${important_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            check_pass "$var is set: ${!var}"
        else
            check_warn "$var is not set"
        fi
    done
}

# Check Git configuration
check_git_config() {
    log_info "Checking Git configuration..."
    
    # Check Git user configuration
    local git_user_name git_user_email
    git_user_name=$(git config --global user.name 2>/dev/null || echo "")
    git_user_email=$(git config --global user.email 2>/dev/null || echo "")
    
    if [[ -n "$git_user_name" ]]; then
        check_pass "Git user.name is set: $git_user_name"
    else
        check_fail "Git user.name is not set"
    fi
    
    if [[ -n "$git_user_email" ]]; then
        check_pass "Git user.email is set: $git_user_email"
    else
        check_fail "Git user.email is not set"
    fi
    
    # Check Git aliases
    if git config --global alias.st >/dev/null 2>&1; then
        check_pass "Git aliases are configured"
    else
        check_warn "Git aliases may not be configured"
    fi
}

# Check SSH configuration
check_ssh_config() {
    log_info "Checking SSH configuration..."
    
    # Check SSH config file
    if [[ -f "$HOME/.ssh/config" ]]; then
        check_pass "SSH config file exists"
        
        # Check for placeholders that weren't replaced
        if grep -q "@.*@" "$HOME/.ssh/config" 2>/dev/null; then
            check_warn "SSH config contains unreplaced placeholders"
        else
            check_pass "SSH config appears to be properly configured"
        fi
    else
        check_warn "SSH config file not found"
    fi
    
    # Check SSH directory permissions
    if [[ -d "$HOME/.ssh" ]]; then
        local ssh_perms
        ssh_perms=$(stat -c %a "$HOME/.ssh" 2>/dev/null || stat -f %A "$HOME/.ssh" 2>/dev/null || echo "unknown")
        if [[ "$ssh_perms" == "700" ]]; then
            check_pass "SSH directory has correct permissions (700)"
        else
            check_warn "SSH directory permissions may be incorrect: $ssh_perms"
        fi
    fi
}

# Check secrets management
check_secrets() {
    log_info "Checking secrets management..."
    
    # Check if age and sops are available
    if command_exists age && command_exists sops; then
        check_pass "Secrets management tools are available"
        
        # Check age keys
        if [[ -f "$HOME/.config/sops/age/keys.txt" ]]; then
            check_pass "Age keys are configured"
        else
            check_warn "Age keys not found"
        fi
        
        # Check SOPS config
        if [[ -f ".sops.yaml" ]]; then
            check_pass "SOPS configuration exists"
        else
            check_warn "SOPS configuration not found"
        fi
    else
        check_warn "Secrets management tools not available"
    fi
}

# Check development environment
check_dev_environment() {
    log_info "Checking development environment..."
    
    # Check programming languages
    local languages=(
        "go:go version"
        "node:node --version"
        "python3:python3 --version"
        "ruby:ruby --version"
    )
    
    for lang_info in "${languages[@]}"; do
        IFS=':' read -r lang_cmd version_cmd <<< "$lang_info"
        if command_exists "$lang_cmd"; then
            local version
            version=$($version_cmd 2>/dev/null | head -1)
            check_pass "$lang_cmd is available: $version"
        else
            check_warn "$lang_cmd is not installed"
        fi
    done
    
    # Check package managers
    local package_managers=(
        "npm"
        "yarn"
        "pip3"
        "gem"
        "cargo"
    )
    
    for pm in "${package_managers[@]}"; do
        if command_exists "$pm"; then
            check_pass "$pm is available"
        else
            check_warn "$pm is not installed"
        fi
    done
}

# Check system health
check_system_health() {
    log_info "Checking system health..."
    
    # Check disk space
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ "$disk_usage" -lt 90 ]]; then
        check_pass "Disk usage is healthy: ${disk_usage}%"
    elif [[ "$disk_usage" -lt 95 ]]; then
        check_warn "Disk usage is getting high: ${disk_usage}%"
    else
        check_fail "Disk usage is critical: ${disk_usage}%"
    fi
    
    # Check if system is up to date (platform specific)
    case "$(uname -s)" in
        Darwin*)
            # macOS - check if Homebrew packages need updates
            if command_exists brew; then
                local outdated_count
                outdated_count=$(brew outdated | wc -l | tr -d ' ')
                if [[ "$outdated_count" -eq 0 ]]; then
                    check_pass "Homebrew packages are up to date"
                else
                    check_warn "$outdated_count Homebrew packages need updates"
                fi
            fi
            ;;
        Linux*)
            # Linux - check if packages need updates (Arch/Ubuntu)
            if command_exists pacman; then
                local updates
                updates=$(checkupdates 2>/dev/null | wc -l || echo "0")
                if [[ "$updates" -eq 0 ]]; then
                    check_pass "System packages are up to date"
                else
                    check_warn "$updates packages need updates"
                fi
            elif command_exists apt; then
                check_pass "Ubuntu/Debian package check skipped (requires sudo)"
            fi
            ;;
    esac
}

# Check for common issues
check_common_issues() {
    log_info "Checking for common issues..."
    
    # Check for conflicting dotfiles
    local backup_files=(
        "$HOME/.zshrc.backup"
        "$HOME/.gitconfig.backup"
        "$HOME/.ssh/config.backup"
    )
    
    for backup_file in "${backup_files[@]}"; do
        if [[ -f "$backup_file" ]]; then
            check_warn "Backup file exists: $backup_file"
        fi
    done
    
    # Check PATH for duplicates
    local path_entries path_unique
    IFS=':' read -ra path_entries <<< "$PATH"
    path_unique=$(printf '%s\n' "${path_entries[@]}" | sort -u | wc -l)
    if [[ "${#path_entries[@]}" -eq "$path_unique" ]]; then
        check_pass "PATH has no duplicate entries"
    else
        check_warn "PATH contains duplicate entries"
    fi
    
    # Check for large files in home directory
    if command_exists find; then
        local large_files
        large_files=$(find "$HOME" -maxdepth 2 -type f -size +100M 2>/dev/null | wc -l)
        if [[ "$large_files" -gt 0 ]]; then
            check_warn "$large_files large files (>100M) found in home directory"
        else
            check_pass "No large files found in home directory"
        fi
    fi
}

# Check host-specific configuration
check_host_config() {
    local repo_root
    repo_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    local hosts_dir="${repo_root}/hosts"
    local host

    if [[ -n "$VALIDATE_HOST" ]]; then
        host="$VALIDATE_HOST"
    else
        host=$(detect_host "$hosts_dir")
    fi

    log_info "Checking host-specific configuration (host: ${host})..."

    # Verify host directory exists
    if [[ ! -d "${hosts_dir}/${host}" ]]; then
        check_warn "No host directory found for '${host}' in hosts/"
        return 0
    fi
    check_pass "Host directory exists: hosts/${host}"

    # Check host setup script
    if [[ -x "${hosts_dir}/${host}/setup.sh" ]]; then
        check_pass "Host setup script is executable: hosts/${host}/setup.sh"
    elif [[ -f "${hosts_dir}/${host}/setup.sh" ]]; then
        check_warn "Host setup script exists but is not executable: hosts/${host}/setup.sh"
    else
        check_warn "No setup script found for host '${host}'"
    fi

    # Load traits
    local traits_summary
    traits_summary=$(host_traits_summary "$hosts_dir" "$host")
    if [[ -n "$traits_summary" ]]; then
        check_pass "Host traits: ${traits_summary}"
    else
        check_warn "No .traits file found for host '${host}'"
    fi

    # ── Trait: desktop ──
    if host_has_trait "$hosts_dir" "$host" "desktop"; then
        _check_service_running "systemd-resolved"
    fi

    # ── Trait: hyprland ──
    if host_has_trait "$hosts_dir" "$host" "hyprland"; then
        check_pass "Host '${host}' has Hyprland trait"

        local hyprland_tools=("Hyprland" "hyprctl" "waybar" "hyprlock" "hypridle" "hyprpaper")
        for tool in "${hyprland_tools[@]}"; do
            if command_exists "$tool"; then
                check_pass "Hyprland component: $tool available"
            else
                check_warn "Hyprland component: $tool not found"
            fi
        done
    fi

    # ── Trait: tlp ──
    if host_has_trait "$hosts_dir" "$host" "tlp"; then
        if command_exists tlp; then
            check_pass "TLP is available"
            _check_service_running "tlp"
        else
            check_warn "TLP not installed (power management)"
        fi
        _check_service_masked "systemd-rfkill"
    fi

    # ── Trait: aio-cooler ──
    if host_has_trait "$hosts_dir" "$host" "aio-cooler"; then
        if command_exists liquidctl; then
            check_pass "liquidctl is available"
        else
            check_fail "liquidctl is missing (required for AIO cooler control)"
        fi
        _check_service_running "liquidctl-${host}"
        _check_service_running "dynamic_led"
    fi

    # ── Trait: asus ──
    if host_has_trait "$hosts_dir" "$host" "asus"; then
        _check_service_running "asusd"
    fi

    # ── Trait: laptop ──
    if host_has_trait "$hosts_dir" "$host" "laptop"; then
        if command_exists brightnessctl; then
            check_pass "brightnessctl available (backlight control)"
        else
            check_warn "brightnessctl not found (backlight control)"
        fi
    fi

    # ── Trait: fingerprint ──
    if host_has_trait "$hosts_dir" "$host" "fingerprint"; then
        if command_exists fprintd-enroll; then
            check_pass "fprintd available (fingerprint auth)"
        else
            check_warn "fprintd not found (fingerprint auth)"
        fi
    fi

    # Verify /etc configs match source (for any host with an etc/ directory)
    if [[ -d "${hosts_dir}/${host}/etc" ]]; then
        local etc_files=()
        while IFS= read -r -d '' f; do
            local rel="${f#${hosts_dir}/${host}/etc/}"
            [[ -n "$rel" ]] && etc_files+=("$rel")
        done < <(find "${hosts_dir}/${host}/etc" -type f -print0 2>/dev/null)

        if [[ ${#etc_files[@]} -gt 0 ]]; then
            _check_etc_config_matches \
                "${hosts_dir}/${host}/etc" \
                "/etc" \
                "${etc_files[@]}"
        fi
    fi
}

# Internal: check that a systemd service is active
_check_service_running() {
    local name="$1"
    if systemctl is-active "${name}.service" &>/dev/null; then
        check_pass "Service ${name} is running"
    else
        check_warn "Service ${name} is not running"
    fi
}

# Internal: check that a systemd service is masked
_check_service_masked() {
    local name="$1"
    local state
    state=$(systemctl is-enabled "${name}.service" 2>/dev/null || true)
    if [[ "$state" == "masked" ]]; then
        check_pass "Service ${name} is masked (expected)"
    else
        check_warn "Service ${name} is not masked (state: ${state:-unknown})"
    fi
}

# Internal: verify /etc config files match their source in the repo
_check_etc_config_matches() {
    local src_root="$1"
    local dst_root="$2"
    shift 2

    for rel in "$@"; do
        local src="${src_root}/${rel}"
        local dst="${dst_root}/${rel}"

        if [[ ! -f "$src" ]]; then
            continue
        fi

        if [[ ! -f "$dst" ]]; then
            check_warn "/etc config missing: ${rel}"
            continue
        fi

        local sum_src sum_dst
        sum_src=$(sha256sum "$src" 2>/dev/null | cut -d' ' -f1)
        sum_dst=$(sudo sha256sum "$dst" 2>/dev/null | cut -d' ' -f1 || true)

        if [[ -n "$sum_src" && "$sum_src" == "$sum_dst" ]]; then
            check_pass "/etc config matches source: ${rel}"
        else
            check_warn "/etc config differs from source: ${rel}"
        fi
    done
}

# Show validation summary
show_summary() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        local status="pass"
        [[ "$CHECKS_WARNING" -gt 0 ]] && status="warn"
        [[ "$CHECKS_FAILED" -gt 0 ]] && status="fail"

        local results_json
        results_json=$(printf '%s\n' "${JSON_RESULTS[@]}" | jq -s '.')

        jq -n \
            --arg status "$status" \
            --argjson passed "$CHECKS_PASSED" \
            --argjson failed "$CHECKS_FAILED" \
            --argjson warnings "$CHECKS_WARNING" \
            --argjson results "$results_json" \
            '{status: $status, passed: $passed, failed: $failed, warnings: $warnings, results: $results}'
        return
    fi

    echo
    log_info "Validation Summary"
    echo "=================="
    echo -e "${GREEN}Passed:${NC}   $CHECKS_PASSED"
    echo -e "${YELLOW}Warnings:${NC} $CHECKS_WARNING"
    echo -e "${RED}Failed:${NC}   $CHECKS_FAILED"
    echo
    
    if [[ "$CHECKS_FAILED" -eq 0 ]]; then
        if [[ "$CHECKS_WARNING" -eq 0 ]]; then
            log_success "🎉 System validation passed with no issues!"
        else
            log_warning "⚠️  System validation passed with $CHECKS_WARNING warnings"
        fi
    else
        log_error "❌ System validation failed with $CHECKS_FAILED errors"
        echo
        log_info "To fix issues:"
        echo "  • Run: ./setup.sh --no-packages to reinstall dotfiles"
        echo "  • Run: ./scripts/install-packages.sh to install missing tools"
        echo "  • Check documentation for manual fixes"
    fi
}

# Main validation function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --host)
                if [[ -z "${2:-}" ]]; then
                    log_error "--host requires a hostname argument"
                    return 1
                fi
                VALIDATE_HOST="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: validate.sh [--json] [--host NAME] [--help]"
                echo "  --json        Emit structured JSON results (for CI/TUI)"
                echo "  --host NAME   Validate for a specific host (default: auto-detect)"
                echo "  --help        Show this help message"
                return 0
                ;;
            *)
                log_error "Unknown argument: $1"
                return 1
                ;;
        esac
    done

    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo
        log_info "🔍 Starting system validation..."
        echo
    fi
    
    check_essential_commands
    [[ "$JSON_OUTPUT" != "true" ]] && echo
    check_modern_tools
    [[ "$JSON_OUTPUT" != "true" ]] && echo
    check_dotfiles
    [[ "$JSON_OUTPUT" != "true" ]] && echo
    check_shell_config
    [[ "$JSON_OUTPUT" != "true" ]] && echo
    check_git_config
    [[ "$JSON_OUTPUT" != "true" ]] && echo
    check_ssh_config
    [[ "$JSON_OUTPUT" != "true" ]] && echo
    check_secrets
    [[ "$JSON_OUTPUT" != "true" ]] && echo
    check_dev_environment
    [[ "$JSON_OUTPUT" != "true" ]] && echo
    check_system_health
    [[ "$JSON_OUTPUT" != "true" ]] && echo
    check_common_issues
    [[ "$JSON_OUTPUT" != "true" ]] && echo
    check_host_config
    
    show_summary
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
