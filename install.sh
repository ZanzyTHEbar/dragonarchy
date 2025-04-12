#!/bin/bash
# ~/dotfiles/install.sh

set -e

# Stow dotfiles
echo "Stowing dotfiles..."
stow -R * -v

# Install zsh dependencies
echo "Installing zsh dependencies..."
bash zsh/dependencies/install.sh

echo "Dotfiles setup complete."
