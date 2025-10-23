#!/bin/bash

set -e

USER_NAME=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$USER_NAME)
ZSH_PATH=$(command -v zsh)
ZSH_CUSTOM="$USER_HOME/.oh-my-zsh/custom"

echo "🎯 Updating system..."
sudo pacman -Syu --noconfirm

echo "🍬 Enabling candy & parallel downloads in pacman..."
sudo sed -i 's/#Color/Color/' /etc/pacman.conf
sudo sed -i 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sudo sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
echo "ILoveCandy" | sudo tee -a /etc/pacman.conf

echo "🛠 Installing essentials..."
sudo pacman -S --noconfirm zsh git curl wget base-devel nano vim lsb-release

### === Install NVIDIA drivers if GPU present === ###
echo "🖥 Checking for NVIDIA GPU..."
if lspci | grep -E "NVIDIA|GeForce"; then
    echo "⚡ NVIDIA GPU detected. Installing drivers..."
    sudo pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils
    echo "✅ NVIDIA drivers installed."
else
    echo "ℹ️ No NVIDIA GPU detected. Skipping NVIDIA drivers."
fi

### === Install yay (AUR helper) === ###
if ! command -v yay &> /dev/null; then
  echo "📦 Installing yay..."
  sudo -u "$USER_NAME" bash -c "
    cd $USER_HOME
    git clone https://aur.archlinux.org/yay.git
    cd yay && makepkg -si --noconfirm
  "
  echo "✅ yay installed."
else
  echo "✅ yay already installed."
fi

### === Install Oh My Zsh === ###
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
  echo "📦 Installing Oh My Zsh..."
  sudo -u "$USER_NAME" sh -c \
  "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "✅ Oh My Zsh already installed."
fi

### === ZSH plugins === ###
echo "🔌 Installing ZSH plugins..."
sudo -u "$USER_NAME" bash -c "
  mkdir -p $ZSH_CUSTOM/plugins
  rm -rf $ZSH_CUSTOM/plugins/{zsh-autosuggestions,zsh-syntax-highlighting,zsh-completions,zsh-autocomplete,fast-syntax-highlighting,zsh-ssh}
  git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
  git clone https://github.com/zsh-users/zsh-completions $ZSH_CUSTOM/plugins/zsh-completions
  git clone https://github.com/marlonrichert/zsh-autocomplete $ZSH_CUSTOM/plugins/zsh-autocomplete
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting $ZSH_CUSTOM/plugins/fast-syntax-highlighting
  git clone https://github.com/sunlei/zsh-ssh $ZSH_CUSTOM/plugins/zsh-ssh
"

### === ZSH config === ###
echo "📁 Backing up old .zshrc (if exists)..."
[ -f $USER_HOME/.zshrc ] && mv $USER_HOME/.zshrc $USER_HOME/.zshrc.bak

echo "🧪 Creating fresh .zshrc..."
cat <<EOL > $USER_HOME/.zshrc
export ZSH="$USER_HOME/.oh-my-zsh"
ZSH_THEME="agnoster"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-autocomplete
  zsh-completions
  zsh-ssh
)

source \$ZSH/oh-my-zsh.sh
EOL

echo "🐚 Setting Zsh as default shell..."
sudo chsh -s "$ZSH_PATH" "$USER_NAME"

echo "✅ Done! Reboot or restart terminal to activate all changes."
echo "🎉 System now supports yay and NVIDIA out of the box."
