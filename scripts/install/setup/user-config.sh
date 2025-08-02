#!/bin/bash
# Prompts for user information and configures Git.

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1"; }

# Check if Git is already configured
if git config --global --get user.name >/dev/null 2>&1 && git config --global --get user.email >/dev/null 2>&1; then
  log_info "Git user name and email are already configured."
  echo "  Name: $(git config --global user.name)"
  echo "  Email: $(git config --global user.email)"
  log_info "Skipping Git configuration."
else
  log_info "Configuring Git user information..."
  # Prompt for user name and email
  USER_NAME=$(gum input --placeholder "Enter your username" --prompt "Username> ")
  USER_EMAIL=$(gum input --placeholder "Enter your email address" --prompt "Email> ")
  
  # Configure Git
  if [[ -n "$USER_NAME" ]]; then
    git config --global user.name "$USER_NAME"
    log_info "Git user name set to: $USER_NAME"
  fi
  
  if [[ -n "$USER_EMAIL" ]]; then
    git config --global user.email "$USER_EMAIL"
    log_info "Git user email set to: $USER_EMAIL"
  fi
  
  log_info "Git user configuration complete."
fi
