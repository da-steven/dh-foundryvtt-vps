#!/bin/bash

# === Bootstrap Environment ===
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../utils" && pwd)"
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"
source "$ENV_LOADER" || { echo "❌ Missing: $ENV_LOADER"; exit 1; }
source "$FILE_UTILS" || { echo "❌ Missing: $FILE_UTILS"; exit 1; }

print_header() {
  echo ""
  echo "╭──────────────────────────────────────────────╮"
  echo "│  💥 Teardown Cloudflare Tunnel"
  echo "╰──────────────────────────────────────────────╯"
}
print_header

# === Config ===
TUNNEL_NAME="${TUNNEL_NAME:-foundry}"
CONFIG_SRC_DIR="$HOME/.cloudflared"
CONFIG_DEST_DIR="${CLOUDFLARE_CONFIG_DIR:-/etc/cloudflared}"
CONFIG_FILE="$CONFIG_DEST_DIR/config.yml"
CERT_FILE="${CLOUDFLARE_CERT_PATH:-$CONFIG_SRC_DIR/cert.pem}"
SERVICE_NAME="cloudflared"

# === Confirm ===
echo ""
echo "⚠️ This will permanently remove the tunnel: $TUNNEL_NAME"
echo "   - Stops systemd services"
echo "   - Deletes the Cloudflare tunnel"
echo "   - Removes local config and credential files"
read -p "Are you sure you want to continue? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo "Aborted by user." && exit 0

# === Stop and disable systemd service ===
echo "🛑 Stopping cloudflared service..."
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true

# === Kill background processes just in case ===
pkill -f "cloudflared tunnel run $TUNNEL_NAME" 2>/dev/null || true

# === Find Tunnel UUID ===
TUNNEL_UUID=$(cloudflared tunnel list 2>/dev/null | awk -v name="$TUNNEL_NAME" '$2 == name { print $1 }')

if [[ -z "$TUNNEL_UUID" ]]; then
  echo "⚠️ No matching tunnel found by name: $TUNNEL_NAME"
else
  echo "🔎 Found tunnel ID: $TUNNEL_UUID"
  echo "🧹 Cleaning stale connections for tunnel..."
  cloudflared tunnel cleanup "$TUNNEL_UUID"

  echo "❌ Deleting tunnel from Cloudflare..."
  if ! cloudflared tunnel delete "$TUNNEL_UUID"; then
    echo "❌ Tunnel deletion failed. You may need to run:"
    echo "   cloudflared tunnel cleanup $TUNNEL_UUID"
    exit 1
  fi
fi

# === Remove local config ===
echo "🧹 Removing local config and credentials..."
sudo rm -f "$CONFIG_FILE"

if [[ -f "$CONFIG_SRC_DIR/$TUNNEL_UUID.json" ]]; then
  rm -f "$CONFIG_SRC_DIR/$TUNNEL_UUID.json"
elif [[ -f "$CONFIG_SRC_DIR/$TUNNEL_NAME.json" ]]; then
  rm -f "$CONFIG_SRC_DIR/$TUNNEL_NAME.json"
fi

# === Ask to uninstall cloudflared ===
read -p "Do you want to uninstall cloudflared from this machine? (y/n): " UNINSTALL
if [[ "$UNINSTALL" =~ ^[Yy]$ ]]; then
  echo "📦 Uninstalling cloudflared..."
  sudo apt remove -y cloudflared
  sudo rm -f /etc/apt/sources.list.d/cloudflared.list
  sudo rm -f /usr/share/keyrings/cloudflare-main.gpg
  sudo apt update
else
  echo "✅ cloudflared remains installed."
fi

# === Done ===
echo ""
echo "✅ Tunnel teardown complete for: $TUNNEL_NAME"