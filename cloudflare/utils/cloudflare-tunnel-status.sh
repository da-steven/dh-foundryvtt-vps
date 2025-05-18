#!/bin/bash

# === Bootstrap Environment ===
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../utils" && pwd)"
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"

if [[ ! -f "$ENV_LOADER" ]]; then
  echo "❌ Could not find: $ENV_LOADER"
  exit 1
fi
source "$ENV_LOADER"

if [[ ! -f "$FILE_UTILS" ]]; then
  echo "❌ Could not find: $FILE_UTILS"
  exit 1
fi
source "$FILE_UTILS"

# === Config ===
TUNNEL_NAME="${TUNNEL_NAME:-foundry}"
CONFIG_FILE="${CLOUDFLARE_CONFIG_DIR:-/etc/cloudflared}/config.yml"
SERVICE_NAME="cloudflared"
HOSTNAME="${TUNNEL_HOSTNAME:-foundry.example.com}"

# === Header ===
echo ""
echo "╭──────────────────────────────────────────────╮"
echo "│ 🔍 Cloudflare Tunnel Status"
echo "╰──────────────────────────────────────────────╯"

# === Step 1: Check cloudflared availability ===
if ! command -v cloudflared > /dev/null 2>&1; then
  echo "❌ cloudflared is not installed. Run the tunnel setup script first."
  exit 1
fi

# === Step 2: List all tunnels ===
echo ""
echo "📋 Registered Cloudflare Tunnels:"
cloudflared tunnel list || {
  echo "⚠️ Unable to list tunnels. Are you logged in?"
  exit 1
}

# === Step 3: Show loaded config ===
echo ""
if [[ -f "$CONFIG_FILE" ]]; then
  echo "🧾 Loaded tunnel config from: $CONFIG_FILE"
  echo ""
  awk '
    /^tunnel:/         { print "🔑 Tunnel ID:     " $2 }
    /credentials-file/ { print "🔐 Credentials:   " $2 }
    /hostname:/        { print "🌐 Hostname:      " $2 }
    /service:/         { print "🔁 Service Route: " $2 }
  ' "$CONFIG_FILE"
else
  echo "⚠️ No config file found at: $CONFIG_FILE"
fi

# === Step 4: Check systemd service ===
echo ""
echo "🛠️ cloudflared systemd service:"
if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "✅ Service is running."
else
  echo "❌ Service is NOT running."
fi

if systemctl is-enabled --quiet "$SERVICE_NAME"; then
  echo "✅ Service is enabled at boot."
else
  echo "⚠️ Service is not enabled. Enable with:"
  echo "   sudo systemctl enable $SERVICE_NAME"
fi

# === Step 5: DNS Resolution ===
echo ""
echo "🌐 DNS lookup for: $HOSTNAME"
A_RECORDS=$(dig +short "$HOSTNAME" A)
AAAA_RECORDS=$(dig +short "$HOSTNAME" AAAA)

if [[ -n "$A_RECORDS" || -n "$AAAA_RECORDS" ]]; then
  [[ -n "$A_RECORDS" ]] && echo "🔎 A:    $A_RECORDS"
  [[ -n "$AAAA_RECORDS" ]] && echo "🔎 AAAA: $AAAA_RECORDS"
else
  echo "⚠️  No A/AAAA records found for $HOSTNAME"
fi

# === Final Output ===
echo ""
echo "🔗 DNS propagation: ${DNS_PROPAGATION_CHECK_URL:-https://www.whatsmydns.net/#A/}$HOSTNAME"