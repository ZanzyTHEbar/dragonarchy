#!/usr/bin/env bash

# System Validation Script
# Validates the dotfiles setup and system health

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((CHECKS_PASSED++))
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    ((CHECKS_WARNING++))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((CHECKS_FAILED++))
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
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
    )
    
    for cmd in "${essential_commands[@]}"; do
        if command_exists "$cmd"; then
            log_success "$cmd is available"
        else
            log_error "$cmd is missing"
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
            log_success "$tool is available"
        else
            log_warning "$tool is missing (optional but recommended)"
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
            log_success "$file exists"
        elif [[ -L "$file" ]]; then
            if [[ -e "$file" ]]; then
                log_success "$file exists (symlink)"
            else
                log_error "$file is a broken symlink"
            fi
        else
            log_error "$file is missing"
        fi
    done
}

# Check shell configuration
check_shell_config() {
    log_info "Checking shell configuration..."
    
    # Check default shell
    if [[ "$SHELL" == */zsh ]]; then
        log_success "Default shell is zsh"
    else
        log_warning "Default shell is not zsh: $SHELL"
    fi
    
    # Check if zsh configuration loads without errors
    if zsh -c 'source ~/.zshrc' 2>/dev/null; then
        log_success "Zsh configuration loads without errors"
    else
        log_error "Zsh configuration has errors"
    fi
    
    # Check environment variables
    local important_vars=(
        "EDITOR"
        "PATH"
        "HOME"
    )
    
    for var in "${important_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            log_success "$var is set: ${!var}"
        else
            log_warning "$var is not set"
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
        log_success "Git user.name is set: $git_user_name"
    else
        log_error "Git user.name is not set"
    fi
    
    if [[ -n "$git_user_email" ]]; then
        log_success "Git user.email is set: $git_user_email"
    else
        log_error "Git user.email is not set"
    fi
    
    # Check Git aliases
    if git config --global alias.st >/dev/null 2>&1; then
        log_success "Git aliases are configured"
    else
        log_warning "Git aliases may not be configured"
    fi
}

# Check SSH configuration
check_ssh_config() {
    log_info "Checking SSH configuration..."
    
    # Check SSH config file
    if [[ -f "$HOME/.ssh/config" ]]; then
        log_success "SSH config file exists"
        
        # Check for placeholders that weren't replaced
        if grep -q "@.*@" "$HOME/.ssh/config" 2>/dev/null; then
            log_warning "SSH config contains unreplaced placeholders"
        else
            log_success "SSH config appears to be properly configured"
        fi
    else
        log_warning "SSH config file not found"
    fi
    
    # Check SSH directory permissions
    if [[ -d "$HOME/.ssh" ]]; then
        local ssh_perms
        ssh_perms=$(stat -c %a "$HOME/.ssh" 2>/dev/null || stat -f %A "$HOME/.ssh" 2>/dev/null || echo "unknown")
        if [[ "$ssh_perms" == "700" ]]; then
            log_success "SSH directory has correct permissions (700)"
        else
            log_warning "SSH directory permissions may be incorrect: $ssh_perms"
        fi
    fi
}

# Check secrets management
check_secrets() {
    log_info "Checking secrets management..."
    
    # Check if age and sops are available
    if command_exists age && command_exists sops; then
        log_success "Secrets management tools are available"
        
        # Check age keys
        if [[ -f "$HOME/.config/sops/age/keys.txt" ]]; then
            log_success "Age keys are configured"
        else
            log_warning "Age keys not found"
        fi
        
        # Check SOPS config
        if [[ -f ".sops.yaml" ]]; then
            log_success "SOPS configuration exists"
        else
            log_warning "SOPS configuration not found"
        fi
    else
        log_warning "Secrets management tools not available"
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
            log_success "$lang_cmd is available: $version"
        else
            log_warning "$lang_cmd is not installed"
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
            log_success "$pm is available"
        else
            log_warning "$pm is not installed"
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
        log_success "Disk usage is healthy: ${disk_usage}%"
    elif [[ "$disk_usage" -lt 95 ]]; then
        log_warning "Disk usage is getting high: ${disk_usage}%"
    else
        log_error "Disk usage is critical: ${disk_usage}%"
    fi
    
    # Check if system is up to date (platform specific)
    case "$(uname -s)" in
        Darwin*)
            # macOS - check if Homebrew packages need updates
            if command_exists brew; then
                local outdated_count
                outdated_count=$(brew outdated | wc -l | tr -d ' ')
                if [[ "$outdated_count" -eq 0 ]]; then
                    log_success "Homebrew packages are up to date"
                else
                    log_warning "$outdated_count Homebrew packages need updates"
                fi
            fi
            ;;
        Linux*)
            # Linux - check if packages need updates (Arch/Ubuntu)
            if command_exists pacman; then
                local updates
                updates=$(checkupdates 2>/dev/null | wc -l || echo "0")
                if [[ "$updates" -eq 0 ]]; then
                    log_success "System packages are up to date"
                else
                    log_warning "$updates packages need updates"
                fi
            elif command_exists apt; then
                log_success "Ubuntu/Debian package check skipped (requires sudo)"
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
            log_warning "Backup file exists: $backup_file"
        fi
    done
    
    # Check PATH for duplicates
    local path_entries path_unique
    IFS=':' read -ra path_entries <<< "$PATH"
    path_unique=$(printf '%s\n' "${path_entries[@]}" | sort -u | wc -l)
    if [[ "${#path_entries[@]}" -eq "$path_unique" ]]; then
        log_success "PATH has no duplicate entries"
    else
        log_warning "PATH contains duplicate entries"
    fi
    
    # Check for large files in home directory
    if command_exists find; then
        local large_files
        large_files=$(find "$HOME" -maxdepth 2 -type f -size +100M 2>/dev/null | wc -l)
        if [[ "$large_files" -gt 0 ]]; then
            log_warning "$large_files large files (>100M) found in home directory"
        else
            log_success "No large files found in home directory"
        fi
    fi
}

# Show validation summary
show_summary() {
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
    echo
    log_info "🔍 Starting system validation..."
    echo
    
    check_essential_commands
    echo
    check_modern_tools
    echo
    check_dotfiles
    echo
    check_shell_config
    echo
    check_git_config
    echo
    check_ssh_config
    echo
    check_secrets
    echo
    check_dev_environment
    echo
    check_system_health
    echo
    check_common_issues
    
    show_summary
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 