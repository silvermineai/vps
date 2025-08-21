#!/bin/bash

#################################################################
# NON-INTERACTIVE Server Hardening & Setup Script for Cloud-Init
#
# v2.0 - Refactored for proper user context and clarity.
#
# Assumes your public SSH key has already been added to the
# 'root' user by your cloud provider.
#################################################################

# Exit immediately if a command exits with a non-zero status.
set -e

# --- ⚙️ CONFIGURATION (EDIT THESE VALUES) ---
NEW_USER="b"
SSH_PORT="22" # Note: Tailscale SSH uses port 22 internally regardless of this setting.
REPOS_TO_CLONE=(
    "silvermine-ai/mywealth.silvermine.ai"
    "silvermine-ai/nde.silvermine.ai"
    "silvermine-ai/do.silvermine.ai"
    "silvermine-ai/www.silvermine.ai"
    "silvermine-ai/familiawindows.silvermine.ai"
)

# --- DERIVED VARIABLES (DO NOT EDIT) ---
USER_HOME="/home/$NEW_USER"
USER_BASHRC="$USER_HOME/.bashrc"
USER_SETUP_SCRIPT="/tmp/user_setup.sh"

# --- Helper function for logging ---
log() {
    echo "--- $1 ---"
}

#################################################################
# PART 1: SYSTEM-LEVEL SETUP (EXECUTED AS ROOT)
#################################################################

log "Updating Packages & Installing Core Utilities"
apt-get update
apt-get upgrade -y
apt-get install -y ufw fail2ban unattended-upgrades curl wget gpg sudo tmux

log "Creating New User: $NEW_USER"
# The --gecos "" part avoids interactive prompts for user information.
adduser --disabled-password --gecos "" "$NEW_USER"
usermod -aG sudo "$NEW_USER"
echo "✅ User '$NEW_USER' created and added to sudo group."

log "Setting up SSH Key for New User"
mkdir -p "$USER_HOME/.ssh"
cp /root/.ssh/authorized_keys "$USER_HOME/.ssh/authorized_keys"
chown -R "$NEW_USER:$NEW_USER" "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
echo "✅ SSH key copied from root to '$NEW_USER'."

log "Configuring Firewall (UFW)"
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT"/tcp
ufw limit "$SSH_PORT"/tcp
# Use --force to avoid the interactive 'y/n' prompt.
ufw --force enable
echo "✅ Firewall enabled."

log "Hardening SSH Daemon"
sed -i "s/^#?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^#?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^#?PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/" /etc/ssh/sshd_config
systemctl restart sshd
echo "✅ SSH daemon hardened."

log "Configuring Fail2ban"
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
echo "✅ Fail2ban configured."

log "Enabling Automatic Security Updates"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOL
echo "✅ Automatic security updates enabled."

log "Installing Tailscale"
curl -fsSL https://tailscale.com/install.sh | sh

#################################################################
# PART 2: USER-SPECIFIC SETUP SCRIPT
# This section creates a script that will be run as the new user.
#################################################################

log "Creating User Setup Script at $USER_SETUP_SCRIPT"

# Note the use of `<<EOF` (without quotes) to allow variable expansion for $USER_HOME
cat > "$USER_SETUP_SCRIPT" <<EOF
#!/bin/bash
set -e

# --- Helper function for logging ---
log_user() {
    echo "--- \$1 ---"
}

# Ensure commands run from the user's home directory
cd "$USER_HOME"

log_user "Appending aliases and exports to .bashrc"
# Note the use of <<'EOT' (with quotes) to prevent expansion of variables inside the block.
cat <<'EOT' >> "$USER_BASHRC"

# --- Custom Settings ---
export IS_SANDBOX=1
export PATH="\$HOME/.local/bin:\$HOME/.venv/bin:\$PATH"

alias omnara="export IS_SANDBOX=1; omnara --dangerously-skip-permissions"
alias yolo="claude --dangerously-skip-permissions"
alias t="tmux a -d"
# --- End Custom Settings ---

EOT

log_user "Installing GitHub CLI (gh)"
(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y))
sudo mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh -y

log_user "Installing Node.js and npm packages"
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g lighthouse @anthropic-ai/claude-code --force

log_user "Installing Python tools into a virtual environment"
sudo apt install -y python3-pip python3-venv
python3 -m venv .venv
source .venv/bin/activate
pip install omnara
deactivate # Good practice to deactivate after use in a script

log_user "Final system updates"
sudo npm update -g
sudo apt-get update -y

log_user "Starting Tailscale and setting up SSH"
# This will output an authentication URL you need to visit.
sudo tailscale up --ssh

# --- GitHub Authentication and Repo Cloning ---
ghlogin() {
    local PAT
    echo -n "🔑 Paste your GitHub PAT and press [Enter]: "
    read -s PAT
    echo
    if [ -z "\$PAT" ]; then
        echo "No token provided. Aborting gh login."
        return 1
    fi
    echo "\$PAT" | gh auth login --git-protocol https --hostname github.com --with-token
}

log_user "Authenticating with GitHub"
ghlogin

log_user "Cloning Repositories"
# Convert the bash array from the parent script into a string to be used here
REPOS_TO_CLONE="${REPOS_TO_CLONE[*]}"
for repo in \$REPOS_TO_CLONE; do
    gh repo clone "\$repo"
done

echo "🎉 User setup complete! You can now log in as '$NEW_USER'."
echo "To get started, run 'tmux' and then 'cd mywealth.silvermine.ai' and 'omnara'."

EOF
#################################################################
# PART 3: EXECUTE THE USER SETUP SCRIPT
#################################################################

log "Running the user-specific setup script as $NEW_USER"
chown "$NEW_USER:$NEW_USER" "$USER_SETUP_SCRIPT"
chmod +x "$USER_SETUP_SCRIPT"

# Execute the script as the new user in a login shell to ensure their environment is sourced.
sudo -u "$NEW_USER" -i /bin/bash "$USER_SETUP_SCRIPT"

log "Cleaning up setup script"
rm "$USER_SETUP_SCRIPT"

echo "🎉 Server Hardening & User Setup Complete! 🎉"
echo "You can now SSH into the server as user '$NEW_USER'."