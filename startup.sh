#!/bin/bash

#################################################################
# NON-INTERACTIVE Server Hardening Script for Cloud-Init
#
# Assumes your public SSH key has already been added to the
# 'root' user by your cloud provider.
#################################################################

# Exit on error
set -e

# --- CONFIGURATION (EDIT THESE VALUES) ---
NEW_USER="b"
# can't change the tailscale port of 22, best practice is > 50000, but we're using 22.
SSH_PORT="22"
PROFILE="~/.bashrc"

# -----------------------------------------

# --- 0. Update package list ---
echo "--- Updating System & Creating User ---"
apt-get update && apt-get upgrade -y
apt-get install -y ufw fail2ban unattended-upgrades

# --- 1. Updating System & Creating User ---
echo "--- Updating System & Creating User ---"
adduser --disabled-password --gecos "" "$NEW_USER"
usermod -aG sudo "$NEW_USER"
echo "✅ User '$NEW_USER' created."

# --- 2. Setting up SSH Key for New User ---
# Copy the SSH keys from the root user to the new user
echo "--- Setting up SSH Key for New User ---"
USER_HOME="/home/$NEW_USER"
mkdir -p "$USER_HOME/.ssh"
# Copy the SSH keys from the root user to the new user
cp /root/.ssh/authorized_keys "$USER_HOME/.ssh/authorized_keys"
# Set correct permissions and ownership
chown -R "$NEW_USER:$NEW_USER" "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
echo "✅ SSH key copied from root to '$NEW_USER'."

# --- 3. Configuring Firewall (UFW) ---
echo "--- Configuring Firewall (UFW) ---"
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT"/tcp
ufw limit "$SSH_PORT"/tcp
echo "y" | ufw enable
echo "✅ Firewall enabled."

# --- 4. Hardening SSH Daemon ---
# Remove root login, password login, and challenge response authentication.
echo "--- Hardening SSH Daemon ---"
sed -i "s/^#?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^#?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^#?PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/" /etc/ssh/sshd_config
# We keep PubkeyAuthentication and UsePAM enabled for broader compatibility
systemctl restart sshd
echo "✅ SSH daemon hardened."

# --- 5. Installing and Configuring Fail2ban ---
# Blocks IP addresses that try to brute force ssh (too many login attemps)
echo "--- Installing and Configuring Fail2ban ---"
cat > /etc/fail2ban/jail.local <<EOL
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = $SSH_PORT
EOL
systemctl restart fail2ban
echo "✅ Fail2ban installed."

# --- 6. Enabling Automatic Security Updates ---
echo "--- Enabling Automatic Security Updates ---"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOL
echo "✅ Automatic security updates enabled."
echo "🎉 Server Hardening Complete! 🎉"

# --- 7. Install tailscale ---
echo "--- Installing Tailscale ---"
curl -fsSL https://tailscale.com/install.sh | sh


#################################################################
# Install packages
# 'root' user by your cloud provider (e.g., Linode, Vultr).
#################################################################
cat << 'EOF' > "$PROFILE"
export IS_SANDBOX=1;
alias omnara="export IS_SANDBOX=1; omnara --dangerously-skip-permissions"
alias yolo="claude --dangerously-skip-permissions"
alias t="tmux a -d
EOF

# Make the newly created script executable (optional, but good practice)
chmod +x "$PROFILE"


#################################################################
# Install packages
# 'root' user by your cloud provider (e.g., Linode, Vultr).
#################################################################
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

ghlogin() {
  local PAT
  # Prompt the user to enter their token, -s makes the input silent (secure).
  echo -n "🔑 Paste your GitHub PAT: "
  read -s PAT
  # Echo a newline for cleaner formatting after the hidden input.
  echo

  # Check if a token was actually entered.
  if [ -z "$PAT" ]; then
    echo "No token provided. Aborting."
    return 1
  fi

  # Pipe the token from the variable into the gh auth login command.
  echo "$PAT" | gh auth login --git-protocol https --hostname github.com --with-token
}

# Install Google Chrome and all dependencies (for google lighthouse)
# apt install -y google-chrome-stable
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt-get -y install google-chrome-stable

# Install npm
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
npm install -g lighthouse \
	@anthropic-ai/claude-code \
	--loglevel info \
	--force

# Install python
apt install -y python3 python3-pip python3-venv
python3 -m venv .venv
source .venv/bin/activate # activate the virtual environment
pip install omnara

# Install tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Aliases
alias omnara="export IS_SANDBOX=1; omnara --dangerously-skip-permissions"

# final updates
npm update -g
sudo apt-get -y update

#################################################################
# Authentication
# 'root' user by your cloud provider (e.g., Linode, Vultr).
#################################################################
# start tmux session
tmux
# set up tailscale ssh
tailscale up --ssh

# note: this requires a server with ipv4 enabled, as github doesn't support ipv6 yet (2025-08-21)
ghlogin

# clone repos
gh repo clone silvermine-ai/mywealth.silvermine.ai
gh repo clone silvermine-ai/nde.silvermine.ai
gh repo clone silvermine-ai/do.silvermine.ai
gh repo clone silvermine-ai/www.silvermine.ai
gh repo clone silvermine-ai/familiawindows.silvermine.ai

# cd mywealth.silvermine.ai
# omnara