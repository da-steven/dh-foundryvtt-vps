#!/bin/bash

# === Bootstrap environment ===
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../utils" && pwd)"
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"

if [[ ! -f "$ENV_LOADER" ]]; then
  echo "❌ Could not find required: $ENV_LOADER"
  exit 1
fi
source "$ENV_LOADER"

if [[ ! -f "$FILE_UTILS" ]]; then
  echo "❌ Could not find required: $FILE_UTILS"
  exit 1
fi
source "$FILE_UTILS"

# === Config ===
TUNNEL_NAME="${TUNNEL_NAME:-foundry}"
CONFIG_SRC_DIR="${CLOUDFLARE_CERT_PATH%/*}"
CONFIG_DIR="${CLOUDFLARE_CONFIG_DIR:-/etc/cloudflared}"
CONFIG_FILE="$CONFIG_DIR/config.yml"
SERVICE_NAME="cloudflared"

echo ""
echo "╭──────────────────────────────────────────────╮"
echo "│ 💥 Tearing Down Cloudflare Tunnel: $TUNNEL_NAME"
echo "╰──────────────────────────────────────────────╯"

# === Confirm ===
echo ""
echo "⚠️  This will:"
echo "   - Stop and disable the systemd service"
echo "   - Delete the tunnel from Cloudflare"
echo "   - Remove local config and credential files"
read -p "Are you sure you want to continue? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo "Aborted by user." && exit 0

# === Step 1: Stop systemd service ===
echo "🛑 Stopping systemd service: $SERVICE_NAME"
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true

# === Step 2: Kill background runs (fallback) ===
pkill -f "cloudflared tunnel run $TUNNEL_NAME" 2>/dev/null || true

# === Step 3: Delete remote tunnel ===
echo "❌ Deleting remote tunnel: $TUNNEL_NAME"
if cloudflared tunnel list 2>/dev/null | grep -qw "$TUNNEL_NAME"; then
  cloudflared tunnel delete "$TUNNEL_NAME"
else
  echo "ℹ️ Tunnel not found in Cloudflare — skipping deletion."
fi

# === Step 4: Remove local config and credentials ===
echo "🧹 Cleaning up local configuration files..."

# Resolve UUID for credential lookup
TUNNEL_UUID=$(cloudflared tunnel list 2>/dev/null | awk -v name="$TUNNEL_NAME" '$2 == name { print $1 }')

# Remove config file
if [[ -f "$CONFIG_FILE" ]]; then
  confirm_overwrite "$CONFIG_FILE" && sudo rm -f "$CONFIG_FILE"
fi

# Remove credentials JSON (UUID or fallback)
if [[ -n "$TUNNEL_UUID" && -f "$CONFIG_SRC_DIR/$TUNNEL_UUID.json" ]]; then
  rm -f "$CONFIG_SRC_DIR/$TUNNEL_UUID.json"
elif [[ -f "$CONFIG_SRC_DIR/$TUNNEL_NAME.json" ]]; then
  rm -f "$CONFIG_SRC_DIR/$TUNNEL_NAME.json"
fi

# === Step 5: Optional uninstall ===
read -p "Do you want to uninstall cloudflared from this system? (y/n): " UNINSTALL
if [[ "$UNINSTALL" =~ ^[Yy]$ ]]; then
  echo "📦 Uninstalling cloudflared..."
  sudo apt remove -y cloudflared
  sudo rm -f /etc/apt/sources.list.d/cloudflared.list
  sudo rm -f /usr/share/keyrings/cloudflare-main.gpg
  sudo apt update
else
  echo "✅ cloudflared remains installed."
fi

# === Final Output ===
echo ""
echo "✅ Tunnel teardown complete for: $TUNNEL_NAME"