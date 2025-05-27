#!/bin/bash
# tools/setup-firewall.sh
# Installs and configures basic firewall and SSH protection via UFW and fail2ban

# === Load environment ===
if [[ -f "utils/load-env.sh" ]]; then
  source "utils/load-env.sh"
elif [[ -f "../utils/load-env.sh" ]]; then
  source "../utils/load-env.sh"
else
  echo "❌ Cannot find utils/load-env.sh" >&2
  exit 1
fi

# === Load helper scripts ===
load_helpers \
  "foundry-config.sh" \
  "file-utils.sh" \
  "tool-utils.sh"

# === Warn user about firewall setup ===
echo ""
echo "⚠️  This script will configure a basic firewall using UFW."
echo "    Incoming connections will be blocked EXCEPT for SSH."
echo "    These defaults are safe for Foundry behind a Cloudflare Tunnel."
echo ""
read -p "Continue with firewall setup? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "❌ Aborted by user."
  exit 1
fi

# === Install and configure UFW ===
echo ""
echo "🛠️  Checking if ufw is installed..."
check_tool ufw || install_tool ufw

echo ""
echo "⚙️  Configuring UFW ..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH

echo ""
echo "✅ Enabling the UFW firewall ..."
sudo ufw --force enable

echo ""
echo "🔎 Current UFW status:"
sudo ufw status verbose

# === Prompt and install fail2ban ===
echo ""
read -p "Install fail2ban to protect SSH from brute force attacks? (y/n): " INSTALL_FAIL2BAN
if [[ "$INSTALL_FAIL2BAN" =~ ^[Yy]$ ]]; then
  echo ""
  echo "🛠️  Checking if fail2ban is installed..."
  check_tool fail2ban || install_tool fail2ban

  echo ""
  echo "🛡️  Configuring fail2ban default jail for SSH..."

  # Create jail.local if missing
  JAIL_LOCAL="/etc/fail2ban/jail.local"
  if [[ ! -f "$JAIL_LOCAL" ]]; then
    sudo bash -c "cat > $JAIL_LOCAL" <<EOF
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 5
findtime = 10m
bantime = 1h
EOF
    echo "✅ jail.local created at $JAIL_LOCAL"
  else
    echo "ℹ️  jail.local already exists. Please review its contents manually at $JAIL_LOCAL"
  fi

  echo ""
  echo "🔁 Restarting fail2ban to apply settings..."
  sudo systemctl restart fail2ban
  echo "✅ fail2ban restarted."

else
  echo "⚠️  Skipping fail2ban installation."
fi

echo ""
echo "🎉 Setup complete. Your server now has basic SSH protection and a firewall configured."