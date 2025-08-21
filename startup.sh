#!/bin/bash

# Update package list
sudo apt-get update -y

# install gh
(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y

# Install Google Chrome and all dependencies
sudo apt-get install -y google-chrome-stable

# 
apt install python3 python3-pip python3-venv
python3 -m venv venv
source venv/bin/activate
pip install omnara && omnara


# Install tailscale
curl -fsSL https://tailscale.com/install.sh | sh


# Aliases
alias yolo="export IS_SANDBOX=1; claude --dangerously-skip-permissions"


# Last steps:
# tailscale up # logs in
# tailscale ip -4 # ssh root@100.98.57.56
