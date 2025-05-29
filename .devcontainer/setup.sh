#!/bin/bash

# Exit on error
set -e

# Update and install dependencies
apt-get update
apt-get install -y neovim git curl jq

# Install yq
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
chmod +x /usr/bin/yq

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
apt-get update
apt-get install -y gh

# Set up Neovim with lazy.nvim
mkdir -p /root/.config/nvim
git clone https://github.com/folke/lazy.nvim.git /root/.local/share/nvim/lazy/lazy.nvim

# Clone dotfiles (replace with your dotfiles repo)
git clone https://github.com/YOUR_USERNAME/dotfiles.git /tmp/dotfiles
cp -r /tmp/dotfiles/nvim/* /root/.config/nvim/
rm -rf /tmp/dotfiles

# Install Neovim plugins with lazy.nvim
nvim --headless -c 'autocmd User LazyDone quitall' -c 'Lazy sync'

# Configure SSH for Codespace access
apt-get install -y openssh-server
mkdir -p /var/run/sshd
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
service ssh start

# Install webapp dependencies
cd /workspaces/REPO_NAME/webapp
npm install
