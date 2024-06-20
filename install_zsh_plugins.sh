#!/bin/bash

# Update and install necessary packages
sudo apt update
sudo apt install -y zsh git curl

# Change default shell to Zsh
chsh -s $(which zsh)

# Check if Oh My Zsh is already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Oh My Zsh is not installed. Please install it before running this script."
  exit 1
fi

# Set custom plugin directory
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# Create custom plugins directory if it doesn't exist
mkdir -p $ZSH_CUSTOM/plugins

# Remove existing plugin directories to avoid conflicts
rm -rf $ZSH_CUSTOM/plugins/zsh-autosuggestions
rm -rf $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
rm -rf $ZSH_CUSTOM/plugins/zsh-completions
rm -rf $ZSH_CUSTOM/plugins/zsh-autocomplete
rm -rf $ZSH_CUSTOM/plugins/fast-syntax-highlighting
rm -rf $ZSH_CUSTOM/plugins/zsh-ssh

# Clone necessary plugins into Oh My Zsh custom plugins directory
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions $ZSH_CUSTOM/plugins/zsh-completions
git clone https://github.com/marlonrichert/zsh-autocomplete $ZSH_CUSTOM/plugins/zsh-autocomplete
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting $ZSH_CUSTOM/plugins/fast-syntax-highlighting
git clone https://github.com/sunlei/zsh-ssh $ZSH_CUSTOM/plugins/zsh-ssh

# Backup existing .zshrc
if [ -f ~/.zshrc ]; then
  mv ~/.zshrc ~/.zshrc.bak
fi

# Create a new .zshrc file with the necessary configurations
cat <<EOL >> ~/.zshrc
# Path to your oh-my-zsh installation.
export ZSH="\$HOME/.oh-my-zsh"

# Set name of the theme to load.
ZSH_THEME="agnoster"

# Enable Oh My Zsh plugins
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-autocomplete
  zsh-completions
  zsh-ssh
)

# Source Oh My Zsh
source \$ZSH/oh-my-zsh.sh

# Define custom ZLE widgets
zle -N insert-unambiguous-or-complete
zle -N menu-search
zle -N recent-paths

# Source additional plugins
source \$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
source \$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
source \$ZSH_CUSTOM/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source \$ZSH_CUSTOM/plugins/zsh-completions/zsh-completions.plugin.zsh
source \$ZSH_CUSTOM/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
source \$ZSH_CUSTOM/plugins/zsh-ssh/zsh-ssh.plugin.zsh
EOL

# Apply changes
zsh -c "source ~/.zshrc"

echo "Installation complete. Please log out and log back in to start using Zsh with the new configuration."
