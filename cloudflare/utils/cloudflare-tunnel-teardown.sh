#!/bin/bash

# === Bootstrap Environment ===
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../utils" && pwd)"
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"
PLATFORM_UTILS="$UTILS_DIR/platform-utils.sh"

for helper in "$ENV_LOADER" "$FILE_UTILS" "$PLATFORM_UTILS"; do
  if [[ -f "$helper" ]]; then
    source "$helper"
  else
    echo "❌ Missing required helper: $helper"
    exit 1
  fi
done

print_header() {
  echo -e "\n\033[1;31m╭──────────────────────────────────────────────╮"
  echo -e   "│ 💥 Cloudflare Tunnel Teardown"
  echo -e   "╰──────────────────────────────────────────────╯\033[0m"
}
print_header

TUNNEL_NAME="${TUNNEL_NAME:-foundry}"
CONFIG_SRC_DIR="${CLOUDFLARE_CERT_PATH%/*}"
CONFIG_DEST_DIR="${CLOUDFLARE_CONFIG_DIR:-/etc/cloudflared}"
CONFIG_FILE="$CONFIG_DEST_DIR/config.yml"
SERVICE_NAME="cloudflared"
CERT_FILE="${CLOUDFLARE_CERT_PATH:-$HOME/.cloudflared/cert.pem}"

echo ""
echo "⚠️ This will stop the systemd service, delete the tunnel, and remove local config/credentials."
read -p "Are you sure you want to continue with teardown of tunnel '$TUNNEL_NAME'? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo "❌ Aborted." && exit 1

# === Check for cert.pem ===
if [[ ! -f "$CERT_FILE" ]]; then
  echo "❌ Missing required authentication certificate:"
  echo "   $CERT_FILE"
  echo ""
  echo "➡️ Please re-authenticate with:"
  echo "   cloudflared tunnel login"
  exit 1
fi

# === Step 1: Stop and remove systemd service ===
echo "🛑 Stopping and disabling systemd service: $SERVICE_NAME"
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true

# Optional: Uninstall systemd template
if [[ -f "/etc/systemd/system/cloudflared.service" ]]; then
  echo "🧹 Removing systemd service file"
  sudo rm -f /etc/systemd/system/cloudflared.service
  sudo systemctl daemon-reload
fi

# === Step 2: Cleanup stale connections ===
TUNNEL_UUID=$(cloudflared tunnel list 2>/dev/null | awk -v name="$TUNNEL_NAME" '$2 == name { print $1 }')
if [[ -n "$TUNNEL_UUID" ]]; then
  echo "🧹 Cleaning up tunnel connections for: $TUNNEL_UUID"
  cloudflared tunnel cleanup "$TUNNEL_UUID"
fi

# === Step 3: Delete the tunnel ===
if cloudflared tunnel list | grep -qw "$TUNNEL_NAME"; then
  echo "❌ Deleting tunnel '$TUNNEL_NAME'..."
  cloudflared tunnel delete "$TUNNEL_NAME"
else
  echo "ℹ️ Tunnel not found — already removed or renamed."
fi

# === Step 4: Remove config and credential files ===
echo "🧹 Removing config: $CONFIG_FILE"
sudo rm -f "$CONFIG_FILE"

echo "🧹 Removing credentials from: $CONFIG_SRC_DIR"
[[ -n "$TUNNEL_UUID" && -f "$CONFIG_SRC_DIR/$TUNNEL_UUID.json" ]] && rm -f "$CONFIG_SRC_DIR/$TUNNEL_UUID.json"
[[ -f "$CONFIG_SRC_DIR/$TUNNEL_NAME.json" ]] && rm -f "$CONFIG_SRC_DIR/$TUNNEL_NAME.json"

# === Final ===
echo ""
echo "✅ Teardown complete for Cloudflare tunnel: $TUNNEL_NAME"