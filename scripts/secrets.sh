#!/usr/bin/env bash

# Unified Secrets Management Script
# Combines functionality from secrets.sh and enhanced-secrets.sh
# Handles complete SOPS/age secrets management with SSH keys, API keys, and templating

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$CONFIG_DIR/secrets"
SOPS_CONFIG="$CONFIG_DIR/.sops.yaml"
AGE_KEYS_DIR="$HOME/.config/sops/age"
AGE_KEYS_FILE="$AGE_KEYS_DIR/keys.txt"
SECRETS_FILE="$SECRETS_DIR/secrets.yaml"

# Options
VERBOSE=false
FORCE=false

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${NC}[DEBUG]${NC} $1"
    fi
}

# Show usage information
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Unified Secrets Management Script
Complete SOPS/age secrets management with SSH keys, API keys, and templating

COMMANDS:
    setup               Initial setup of secrets management
    create              Create encrypted secrets from user input
    create-enhanced     Create comprehensive secrets template
    install             Install all secrets to current machine
    install-keys        Install SSH private keys from secrets
    install-api         Install API keys and environment variables
    template-ssh        Apply SSH config templating
    edit                Edit encrypted secrets file
    decrypt             View decrypted secrets (be careful!)
    verify              Verify secrets can be decrypted
    add KEY VALUE       Add or update a single secret
    rekey               Update encryption keys for all secrets
    generate-key        Generate new age encryption key
    backup              Backup secrets and keys
    restore FILE        Restore from backup file
    status              Show secrets management status

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --force             Force overwrite existing files

EXAMPLES:
    $0 setup                        # Initial setup
    $0 create-enhanced              # Create comprehensive secrets
    $0 install                      # Install all secrets
    $0 install-keys                 # Only install SSH keys
    $0 template-ssh                 # Apply SSH config templating
    $0 backup                       # Backup secrets and keys

EOF
}

# Parse command line options
parse_options() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                # Unknown option, break to handle commands
                break
                ;;
        esac
    done
}

# Check if required tools are available
check_requirements() {
    local missing_tools=()
    
    if ! command -v age >/dev/null 2>&1; then
        missing_tools+=("age")
    fi
    
    if ! command -v sops >/dev/null 2>&1; then
        missing_tools+=("sops")
    fi
    
    if ! command -v yq >/dev/null 2>&1; then
        missing_tools+=("yq")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install them first:"
        log_info "  • age: https://github.com/FiloSottile/age"
        log_info "  • sops: https://github.com/mozilla/sops"
        log_info "  • yq: https://github.com/mikefarah/yq"
        exit 1
    fi
}

# Generate age encryption key
generate_age_key() {
    log_info "Generating age encryption key..."
    
    mkdir -p "$AGE_KEYS_DIR"
    
    if [[ -f "$AGE_KEYS_FILE" && "$FORCE" != "true" ]]; then
        log_warning "Age key already exists at $AGE_KEYS_FILE"
        read -p "Overwrite existing key? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing key"
            return 0
        fi
    fi
    
    age-keygen -o "$AGE_KEYS_FILE"
    chmod 600 "$AGE_KEYS_FILE"
    
    log_success "Age key generated at $AGE_KEYS_FILE"
    
    # Show public key
    echo
    log_info "Your public key (add this to .sops.yaml):"
    age-keygen -y "$AGE_KEYS_FILE"
    echo
}

# Setup SOPS configuration
setup_sops_config() {
    log_info "Setting up SOPS configuration..."
    
    if [[ ! -f "$AGE_KEYS_FILE" ]]; then
        log_error "Age key not found. Run 'generate-key' first."
        exit 1
    fi
    
    local public_key
    public_key=$(age-keygen -y "$AGE_KEYS_FILE")
    
    # Create .sops.yaml
    cat > "$SOPS_CONFIG" << EOF
keys:
  - &main_key $public_key

creation_rules:
  - path_regex: .*\\.yaml$
    key_groups:
      - age:
          - *main_key
  - path_regex: .*\\.yml$
    key_groups:
      - age:
          - *main_key
  - path_regex: .*\\.json$
    key_groups:
      - age:
          - *main_key
EOF
    
    log_success "SOPS configuration created at $SOPS_CONFIG"
}

# Initial setup
setup_secrets() {
    log_info "Setting up secrets management..."
    
    check_requirements
    
    # Create directories
    mkdir -p "$SECRETS_DIR"
    mkdir -p "$AGE_KEYS_DIR"
    
    # Generate key if it doesn't exist
    if [[ ! -f "$AGE_KEYS_FILE" ]]; then
        generate_age_key
    fi
    
    # Setup SOPS config
    setup_sops_config
    
    # Create initial secrets file if it doesn't exist
    if [[ ! -f "$SECRETS_FILE" ]]; then
        log_info "Creating initial secrets file..."
        create_basic_secrets_file
    fi
    
    log_success "Secrets management setup completed"
    show_status
}

# Create basic secrets file (simple template)
create_basic_secrets_file() {
    log_debug "Creating basic secrets template..."
    
    # Create template secrets file
    cat > /tmp/secrets_basic_$$.yaml << EOF
# Basic Secrets Configuration
# This file is encrypted with SOPS and age

# SSH Configuration
ssh:
  emissium_api_ip: "your-api-server-ip"
  emissium_coolify_ip: "your-coolify-server-ip"
  emissium_staging_ip: "your-staging-server-ip"

# Git Configuration  
git:
  signing_key: "your-git-signing-key"
  signing_key_id: "your-signing-key-id"

# Environment Variables
env:
  GITHUB_TOKEN: "your-github-token"
  OPENAI_API_KEY: "your-openai-key"

# Add your custom secrets here
custom:
  example_secret: "example-value"
EOF
    
    # Encrypt the template
    sops --encrypt /tmp/secrets_basic_$$.yaml > "$SECRETS_FILE"
    rm /tmp/secrets_basic_$$.yaml
    
    log_success "Basic secrets file created at $SECRETS_FILE"
}

# Create comprehensive secrets file (enhanced template)
create_enhanced_secrets_file() {
    log_info "Creating comprehensive secrets file..."
    
    check_requirements
    
    if [[ ! -f "$SOPS_CONFIG" ]]; then
        log_error "SOPS configuration not found. Run 'setup' first."
        exit 1
    fi
    
    # Create temporary file for secrets
    local temp_file="/tmp/secrets_$$.yaml"
    
    cat > "$temp_file" << 'EOF'
# Comprehensive Secrets Configuration
# This file is encrypted with SOPS and age

# SSH Configuration
ssh:
  # Server IP addresses for SSH config templating
  emissium_api_ip: "your-api-server-ip"
  emissium_coolify_ip: "your-coolify-server-ip"
  emissium_staging_ip: "your-staging-server-ip"
  
  # SSH Private Keys (paste your actual private keys here)
  ssh_key_spacedragon: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    # Paste your spacedragon private key here
    -----END OPENSSH PRIVATE KEY-----
  
  ssh_key_emissium: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    # Paste your emissium private key here
    -----END OPENSSH PRIVATE KEY-----
  
  ssh_key_detos: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    # Paste your detos private key here
    -----END OPENSSH PRIVATE KEY-----
  
  ssh_key_zac: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    # Paste your zac private key here
    -----END OPENSSH PRIVATE KEY-----

# API Keys and Tokens
api:
  openrouter_key: "your-openrouter-api-key"
  github_token: "your-github-token"
  openai_api_key: "your-openai-api-key"
  anthropic_api_key: "your-anthropic-api-key"

# Environment Variables
env:
  GITHUB_TOKEN: "your-github-token"
  OPENAI_API_KEY: "your-openai-api-key"
  ANTHROPIC_API_KEY: "your-anthropic-api-key"
  OPENROUTER_API_KEY: "your-openrouter-api-key"

# Git Configuration
git:
  signing_key: "your-git-signing-key"
  signing_key_id: "your-signing-key-id"

# Additional Secrets
custom:
  database_password: "your-database-password"
  jwt_secret: "your-jwt-secret"
  encryption_key: "your-encryption-key"
EOF
    
    # Open editor for user to fill in secrets
    log_info "Opening editor to configure secrets..."
    "${EDITOR:-nano}" "$temp_file"
    
    # Encrypt and save
    if sops --encrypt "$temp_file" > "$SECRETS_FILE"; then
        log_success "Secrets created and encrypted"
    else
        log_error "Failed to encrypt secrets"
        rm -f "$temp_file"
        exit 1
    fi
    
    rm -f "$temp_file"
}

# Create secrets interactively (basic version)
create_basic_secrets() {
    log_info "Creating basic secrets interactively..."
    
    check_requirements
    
    if [[ ! -f "$SOPS_CONFIG" ]]; then
        log_error "SOPS configuration not found. Run 'setup' first."
        exit 1
    fi
    
    # Create temporary file for secrets
    local temp_file="/tmp/secrets_basic_$$.yaml"
    
    cat > "$temp_file" << EOF
# Basic Secrets Configuration
# Enter your secrets below

ssh:
  emissium_api_ip: ""
  emissium_coolify_ip: ""
  emissium_staging_ip: ""

git:
  signing_key: ""
  signing_key_id: ""

env:
  GITHUB_TOKEN: ""
  OPENAI_API_KEY: ""

custom:
  example_secret: ""
EOF
    
    # Open editor for user to fill in secrets
    log_info "Opening editor to configure basic secrets..."
    "${EDITOR:-nano}" "$temp_file"
    
    # Encrypt and save
    if sops --encrypt "$temp_file" > "$SECRETS_FILE"; then
        log_success "Basic secrets created and encrypted"
    else
        log_error "Failed to encrypt secrets"
        rm -f "$temp_file"
        exit 1
    fi
    
    rm -f "$temp_file"
}

# Install SSH private keys from secrets
install_ssh_keys() {
    log_info "Installing SSH private keys from secrets..."
    
    check_requirements
    
    if [[ ! -f "$SECRETS_FILE" ]]; then
        log_error "Secrets file not found"
        exit 1
    fi
    
    # Decrypt secrets to temporary file
    local temp_file="/tmp/secrets_keys_$$.yaml"
    if ! sops --decrypt "$SECRETS_FILE" > "$temp_file"; then
        log_error "Failed to decrypt secrets"
        exit 1
    fi
    
    # Ensure SSH directory exists with correct permissions
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    # Install SSH private keys
    local ssh_keys=(
        "ssh_key_spacedragon:spacedragon"
        "ssh_key_emissium:emissium"
        "ssh_key_detos:detos" 
        "ssh_key_zac:zac"
    )
    
    for key_entry in "${ssh_keys[@]}"; do
        IFS=':' read -r secret_key filename <<< "$key_entry"
        
        local key_content
        key_content=$(yq eval ".ssh.${secret_key} // \"\"" "$temp_file")
        
        if [[ -n "$key_content" && "$key_content" != "null" && "$key_content" != '""' ]]; then
            log_info "Installing SSH key: $filename"
            echo "$key_content" > "$HOME/.ssh/$filename"
            chmod 600 "$HOME/.ssh/$filename"
            log_success "Installed SSH key: $filename"
        else
            log_debug "SSH key not found in secrets: $secret_key"
        fi
    done
    
    # Install public keys from stow package if they exist
    local pub_keys_dir="$CONFIG_DIR/packages/ssh/.ssh"
    if [[ -d "$pub_keys_dir" ]]; then
        log_info "Installing SSH public keys..."
        for pub_key in "$pub_keys_dir"/*.pub; do
            if [[ -f "$pub_key" ]]; then
                local basename=$(basename "$pub_key")
                cp "$pub_key" "$HOME/.ssh/$basename"
                chmod 644 "$HOME/.ssh/$basename"
                log_debug "Installed public key: $basename"
            fi
        done
    fi
    
    # Clean up
    rm -f "$temp_file"
    
    log_success "SSH keys installation completed"
}

# Template SSH configuration with secrets
template_ssh_config() {
    log_info "Applying SSH configuration templating..."
    
    check_requirements
    
    if [[ ! -f "$SECRETS_FILE" ]]; then
        log_error "Secrets file not found"
        exit 1
    fi
    
    if [[ ! -f "$HOME/.ssh/config" ]]; then
        log_error "SSH config file not found"
        exit 1
    fi
    
    # Decrypt secrets to temporary file
    local temp_file="/tmp/secrets_ssh_$$.yaml"
    if ! sops --decrypt "$SECRETS_FILE" > "$temp_file"; then
        log_error "Failed to decrypt secrets"
        exit 1
    fi
    
    # Extract IP addresses
    local emissium_api_ip emissium_coolify_ip emissium_staging_ip
    emissium_api_ip=$(yq eval '.ssh.emissium_api_ip // ""' "$temp_file")
    emissium_coolify_ip=$(yq eval '.ssh.emissium_coolify_ip // ""' "$temp_file")
    emissium_staging_ip=$(yq eval '.ssh.emissium_staging_ip // ""' "$temp_file")
    
    # Create backup of SSH config
    cp "$HOME/.ssh/config" "$HOME/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Apply templating
    local ssh_config="$HOME/.ssh/config"
    local changes_made=false
    
    if [[ -n "$emissium_api_ip" && "$emissium_api_ip" != "null" && "$emissium_api_ip" != '""' ]]; then
        log_info "Templating SSH config with API server IP: $emissium_api_ip"
        sed -i "s/@EMISSIUM_API_IP@/$emissium_api_ip/g" "$ssh_config"
        changes_made=true
    fi
    
    if [[ -n "$emissium_coolify_ip" && "$emissium_coolify_ip" != "null" && "$emissium_coolify_ip" != '""' ]]; then
        log_info "Templating SSH config with Coolify server IP: $emissium_coolify_ip"
        sed -i "s/@EMISSIUM_COOLIFY_IP@/$emissium_coolify_ip/g" "$ssh_config"
        changes_made=true
    fi
    
    if [[ -n "$emissium_staging_ip" && "$emissium_staging_ip" != "null" && "$emissium_staging_ip" != '""' ]]; then
        log_info "Templating SSH config with staging server IP: $emissium_staging_ip"
        sed -i "s/@EMISSIUM_STAGING_IP@/$emissium_staging_ip/g" "$ssh_config"
        changes_made=true
    fi
    
    # Clean up
    rm -f "$temp_file"
    
    if [[ "$changes_made" == "true" ]]; then
        log_success "SSH configuration templating completed"
    else
        log_warning "No templating changes were made (check your secrets contain IP addresses)"
    fi
}

# Install API keys and environment variables
install_api_keys() {
    log_info "Installing API keys and environment variables..."
    
    check_requirements
    
    if [[ ! -f "$SECRETS_FILE" ]]; then
        log_error "Secrets file not found"
        exit 1
    fi
    
    # Decrypt secrets to temporary file
    local temp_file="/tmp/secrets_api_$$.yaml"
    if ! sops --decrypt "$SECRETS_FILE" > "$temp_file"; then
        log_error "Failed to decrypt secrets"
        exit 1
    fi
    
    # Create API keys directory
    mkdir -p "$HOME/.config/api"
    chmod 700 "$HOME/.config/api"
    
    # Install API keys
    local api_keys=(
        "openrouter_key:openrouter.key"
        "github_token:github.token"
        "openai_api_key:openai.key"
        "anthropic_api_key:anthropic.key"
    )
    
    for key_entry in "${api_keys[@]}"; do
        IFS=':' read -r secret_key filename <<< "$key_entry"
        
        local key_content
        key_content=$(yq eval ".api.${secret_key} // \"\"" "$temp_file")
        
        if [[ -n "$key_content" && "$key_content" != "null" && "$key_content" != '""' ]]; then
            echo "$key_content" > "$HOME/.config/api/$filename"
            chmod 600 "$HOME/.config/api/$filename"
            log_success "Installed API key: $filename"
        else
            log_debug "API key not found in secrets: $secret_key"
        fi
    done
    
    # Create environment file
    local env_file="$HOME/.config/secrets/env"
    mkdir -p "$(dirname "$env_file")"
    
    # Extract all environment variables
    if yq eval '.env // {}' "$temp_file" | yq eval 'to_entries | .[] | "export " + .key + "=\"" + .value + "\""' > "$env_file"; then
        if [[ -s "$env_file" ]]; then
            log_success "Environment variables written to $env_file"
            log_info "Source this file in your shell configuration"
        fi
    fi
    
    # Clean up
    rm -f "$temp_file"
    
    log_success "API keys installation completed"
}

# Comprehensive secrets installation
install_all_secrets() {
    log_info "Installing all secrets to system..."
    
    # Install SSH keys
    log_info "=== Installing SSH Keys ==="
    install_ssh_keys
    echo
    
    # Template SSH config
    log_info "=== Templating SSH Configuration ==="
    template_ssh_config
    echo
    
    # Install API keys
    log_info "=== Installing API Keys ==="
    install_api_keys
    
    log_success "Complete secrets installation finished"
}

# Edit encrypted secrets
edit_secrets() {
    log_info "Editing encrypted secrets..."
    
    check_requirements
    
    if [[ ! -f "$SECRETS_FILE" ]]; then
        log_error "Secrets file not found. Run 'create' or 'create-enhanced' first."
        exit 1
    fi
    
    sops "$SECRETS_FILE"
}

# Decrypt and view secrets
decrypt_secrets() {
    log_warning "Decrypting and displaying secrets - be careful!"
    
    check_requirements
    
    if [[ ! -f "$SECRETS_FILE" ]]; then
        log_error "Secrets file not found"
        exit 1
    fi
    
    sops --decrypt "$SECRETS_FILE"
}

# Verify secrets can be decrypted
verify_secrets() {
    log_info "Verifying secrets decryption..."
    
    check_requirements
    
    if [[ ! -f "$SECRETS_FILE" ]]; then
        log_error "Secrets file not found"
        exit 1
    fi
    
    if sops --decrypt "$SECRETS_FILE" >/dev/null 2>&1; then
        log_success "Secrets can be decrypted successfully"
    else
        log_error "Failed to decrypt secrets"
        exit 1
    fi
}

# Add or update a single secret
add_secret() {
    local key="$1"
    local value="$2"
    
    log_info "Adding secret: $key"
    
    check_requirements
    
    if [[ ! -f "$SECRETS_FILE" ]]; then
        log_error "Secrets file not found. Run 'create' first."
        exit 1
    fi
    
    # Decrypt, update, and re-encrypt
    local temp_file="/tmp/secrets_update_$$.yaml"
    sops --decrypt "$SECRETS_FILE" > "$temp_file"
    
    # Update the value using yq
    yq eval ".$key = \"$value\"" -i "$temp_file"
    
    # Re-encrypt
    sops --encrypt "$temp_file" > "$SECRETS_FILE"
    rm -f "$temp_file"
    
    log_success "Secret '$key' updated"
}

# Rekey all secrets files
rekey_secrets() {
    log_info "Rekeying secrets files..."
    
    check_requirements
    
    if [[ ! -f "$AGE_KEYS_FILE" ]]; then
        log_error "Age key not found"
        exit 1
    fi
    
    # Update SOPS config
    setup_sops_config
    
    # Rekey the secrets file
    if [[ -f "$SECRETS_FILE" ]]; then
        log_info "Rekeying $SECRETS_FILE..."
        sops updatekeys "$SECRETS_FILE"
        log_success "Secrets file rekeyed"
    else
        log_warning "No secrets file found to rekey"
    fi
}

# Backup secrets and keys
backup_secrets() {
    log_info "Creating secrets backup..."
    
    local backup_dir="$HOME/secrets-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup encrypted secrets
    if [[ -f "$SECRETS_FILE" ]]; then
        cp "$SECRETS_FILE" "$backup_dir/"
        log_info "Backed up encrypted secrets"
    fi
    
    # Backup SOPS config
    if [[ -f "$SOPS_CONFIG" ]]; then
        cp "$SOPS_CONFIG" "$backup_dir/"
        log_info "Backed up SOPS configuration"
    fi
    
    # Backup age keys
    if [[ -d "$AGE_KEYS_DIR" ]]; then
        cp -r "$AGE_KEYS_DIR" "$backup_dir/"
        log_info "Backed up age keys"
    fi
    
    # Backup SSH directory (excluding private keys for security)
    if [[ -d "$HOME/.ssh" ]]; then
        mkdir -p "$backup_dir/ssh"
        cp "$HOME/.ssh/config" "$backup_dir/ssh/" 2>/dev/null || true
        cp "$HOME/.ssh"/*.pub "$backup_dir/ssh/" 2>/dev/null || true
        log_info "Backed up SSH configuration and public keys"
    fi
    
    log_success "Backup created at: $backup_dir"
}

# Show secrets management status
show_status() {
    log_info "Secrets Management Status:"
    echo
    
    # Check age key
    if [[ -f "$AGE_KEYS_FILE" ]]; then
        log_success "✓ Age encryption key: $AGE_KEYS_FILE"
    else
        log_error "✗ Age encryption key not found"
    fi
    
    # Check SOPS config
    if [[ -f "$SOPS_CONFIG" ]]; then
        log_success "✓ SOPS configuration: $SOPS_CONFIG"
    else
        log_error "✗ SOPS configuration not found"
    fi
    
    # Check secrets file
    if [[ -f "$SECRETS_FILE" ]]; then
        log_success "✓ Secrets file: $SECRETS_FILE"
        if sops --decrypt "$SECRETS_FILE" >/dev/null 2>&1; then
            log_success "✓ Secrets file can be decrypted"
        else
            log_error "✗ Cannot decrypt secrets file"
        fi
    else
        log_warning "⚠ Secrets file not found"
    fi
    
    # Check required tools
    local tools=("age" "sops" "yq")
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "✓ Tool available: $tool"
        else
            log_error "✗ Tool missing: $tool"
        fi
    done
    
    echo
}

# Main function
main() {
    # Parse options first
    parse_options "$@"
    
    # Remove parsed options from arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose|--force)
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Handle commands
    case "${1:-}" in
        setup)
            setup_secrets
            ;;
        create)
            create_basic_secrets
            ;;
        create-enhanced)
            create_enhanced_secrets_file
            ;;
        install)
            install_all_secrets
            ;;
        install-keys)
            install_ssh_keys
            ;;
        install-api)
            install_api_keys
            ;;
        template-ssh)
            template_ssh_config
            ;;
        edit)
            edit_secrets
            ;;
        decrypt)
            decrypt_secrets
            ;;
        verify)
            verify_secrets
            ;;
        add)
            if [[ $# -lt 3 ]]; then
                log_error "Usage: $0 add KEY VALUE"
                exit 1
            fi
            add_secret "$2" "$3"
            ;;
        rekey)
            rekey_secrets
            ;;
        generate-key)
            generate_age_key
            ;;
        backup)
            backup_secrets
            ;;
        status)
            show_status
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            log_error "Unknown command: ${1:-}"
            usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 