#!/bin/bash

# === Bootstrap Environment ===
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../utils" && pwd)"
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"

if [[ ! -f "$ENV_LOADER" ]]; then
  echo "❌ Missing required: $ENV_LOADER"
  exit 1
fi
source "$ENV_LOADER"

if [[ ! -f "$FILE_UTILS" ]]; then
  echo "❌ Missing required: $FILE_UTILS"
  exit 1
fi
source "$FILE_UTILS"

# === Config ===
TUNNEL_NAME="${TUNNEL_NAME:-foundry}"
CONFIG_DIR="${CLOUDFLARE_CONFIG_DIR:-/etc/cloudflared}"
CONFIG_FILE="$CONFIG_DIR/config.yml"
SERVICE_NAME="cloudflared"

echo ""
echo "╭──────────────────────────────────────────────╮"
echo "│ 🔍 Verifying Cloudflare Tunnel: $TUNNEL_NAME"
echo "╰──────────────────────────────────────────────╯"

# === Step 1: Check config file ===
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  echo "   This file is expected after successful tunnel setup."
  exit 1
fi

# === Step 2: Extract and validate fields ===
UUID=$(awk -F: '/^tunnel:/ { gsub(/ /,"",$2); print $2; exit }' "$CONFIG_FILE")
CREDENTIAL_FILE=$(awk -F: '/credentials-file:/ { gsub(/ /,"",$2); print $2; exit }' "$CONFIG_FILE")
HOSTNAME=$(awk '/hostname:/ { gsub(/[" ]/,"",$2); print $2; exit }' "$CONFIG_FILE")

if [[ -z "$UUID" || -z "$CREDENTIAL_FILE" || -z "$HOSTNAME" ]]; then
  echo "❌ Failed to extract tunnel UUID, credentials file, or hostname from config."
  exit 1
fi

if [[ ! -f "$CREDENTIAL_FILE" ]]; then
  echo "❌ Credentials file not found: $CREDENTIAL_FILE"
  echo "   You may need to re-run tunnel login and setup."
  exit 1
fi

echo "✅ Tunnel UUID:           $UUID"
echo "✅ Credentials file:      $CREDENTIAL_FILE"
echo "✅ Hostname:              $HOSTNAME"

# === Step 3: DNS A/AAAA Records ===
echo ""
echo "🌐 Checking DNS records for: $HOSTNAME"
A_RECORDS=$(dig +short "$HOSTNAME" A)
AAAA_RECORDS=$(dig +short "$HOSTNAME" AAAA)

if [[ -n "$A_RECORDS" || -n "$AAAA_RECORDS" ]]; then
  echo "✅ DNS resolution successful."
  [[ -n "$A_RECORDS" ]] && echo "🔎 A:     $A_RECORDS"
  [[ -n "$AAAA_RECORDS" ]] && echo "🔎 AAAA:  $AAAA_RECORDS"
else
  echo "❌ DNS lookup failed for $HOSTNAME"
  echo "   Check propagation: https://www.whatsmydns.net/#A/$HOSTNAME"
  exit 1
fi

# === Step 4: systemd check ===
echo ""
echo "🛠️ Checking systemd service: $SERVICE_NAME"

if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "✅ Service is active."
else
  echo "❌ Service is not running."
  echo "   Start it with: sudo systemctl start $SERVICE_NAME"
  exit 1
fi

if systemctl is-enabled --quiet "$SERVICE_NAME"; then
  echo "✅ Service is enabled on boot."
else
  echo "⚠️ Service is not enabled on boot."
  echo "   Run: sudo systemctl enable $SERVICE_NAME"
fi

# === Step 5: HTTPS Check ===
echo ""
echo "🌐 Testing HTTPS: https://$HOSTNAME"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$HOSTNAME")

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
  echo "✅ HTTPS response: $HTTP_CODE"
else
  echo "⚠️  Unexpected HTTP code: $HTTP_CODE"
  echo "   Try visiting in a browser or inspect container logs."
fi

# === Final Output ===
echo ""
echo "🎯 Tunnel verification complete!"
echo "🔗 Visit: https://$HOSTNAME"
echo "🧪 DNS:  https://www.whatsmydns.net/#A/$HOSTNAME"
echo "📋 Logs: journalctl -u $SERVICE_NAME"