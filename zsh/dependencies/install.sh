#!/bin/bash
# ~/dotfiles/zsh/dependencies/install.sh

set -e

# Paths
ZSH_DIR="$HOME/.oh-my-zsh"
PLUGIN_DIR="$ZSH_DIR/custom/plugins"
PLUGINS_FILE="$(dirname "$0")/plugins.txt"

# Ensure script is run from dotfiles/zsh/dependencies/
if [[ ! -f "$PLUGINS_FILE" ]]; then
    echo "Error: plugins.txt not found!"
    exit 1
fi

# Install oh-my-zsh if not present
if [[ ! -d "$ZSH_DIR" ]]; then
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended
else
    echo "oh-my-zsh already installed."
fi

# TODO: install powerlevel10k theme: git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
# Check if theme is installed, if not install it


# Create custom plugins directory
mkdir -p "$PLUGIN_DIR"

# Read plugins.txt and clone/update each plugin
while IFS= read -r repo_url || [[ -n "$repo_url" ]]; do
    if [[ -z "$repo_url" ]]; then continue; fi
    plugin_name=$(basename "$repo_url" .git)
    plugin_path="$PLUGIN_DIR/$plugin_name"

    if [[ -d "$plugin_path" ]]; then
        echo "Updating $plugin_name..."
        git -C "$plugin_path" pull origin master || echo "Failed to update $plugin_name"
    else
        echo "Installing $plugin_name..."
        git clone "$repo_url" "$plugin_path" || echo "Failed to install $plugin_name"
    fi
done < "$PLUGINS_FILE"

echo "Zsh dependencies installed/updated."
