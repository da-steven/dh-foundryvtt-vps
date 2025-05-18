#!/bin/bash

# === Bootstrap Environment ===
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../utils" && pwd)"
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"
PLATFORM_UTILS="$UTILS_DIR/platform-utils.sh"

# Load helpers
for helper in "$ENV_LOADER" "$FILE_UTILS" "$PLATFORM_UTILS"; do
  if [[ -f "$helper" ]]; then
    source "$helper"
  else
    echo "❌ Missing: $helper"
    exit 1
  fi
done

# === Header ===
echo -e "\n\033[1;36m╭──────────────────────────────────────────────╮"
echo -e   "│ 🛠️  Cloudflare Tunnel Setup (Single Instance) │"
echo -e   "╰──────────────────────────────────────────────╯\033[0m"

# === Config ===
CONFIG_SRC_DIR="${CLOUDFLARE_CERT_PATH%/*}"
CONFIG_DEST_DIR="${CLOUDFLARE_CONFIG_DIR:-/etc/cloudflared}"
CONFIG_FILE="$CONFIG_DEST_DIR/config.yml"
TUNNEL_NAME="${TUNNEL_NAME:-foundry}"
TUNNEL_HOSTNAME="${TUNNEL_HOSTNAME:-foundry.example.com}"
FOUNDRY_PORT="${FOUNDRY_PORT:-30000}"

# === Step 1: Ensure cloudflared is installed ===
echo "🔍 Checking for cloudflared..."
if ! command -v cloudflared > /dev/null 2>&1; then
  echo "⚙️ cloudflared not found. Attempting auto-install..."
  download_binary_for_arch \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-" \
    cloudflared \
    /usr/local/bin/cloudflared || {
      echo "❌ Auto-install failed. Please install manually:"
      echo "   https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install/"
      exit 1
  }
  command -v cloudflared > /dev/null || {
    echo "❌ cloudflared install verification failed."
    exit 1
  }
fi
echo "✅ cloudflared found at: $(command -v cloudflared)"

# === Step 2: Ensure login ===
if [[ ! -f "$CLOUDFLARE_CERT_PATH" ]]; then
  echo "🌐 Logging into Cloudflare..."
  cloudflared tunnel login || {
    echo "❌ Login failed. Exiting."
    exit 1
  }
else
  echo "✅ Cloudflare cert.pem found"
fi

# === Step 3: Create or reuse tunnel ===
if cloudflared tunnel list | grep -qw "$TUNNEL_NAME"; then
  echo "⚠️ Tunnel '$TUNNEL_NAME' already exists."
  confirm_overwrite "$CONFIG_FILE" || {
    echo "⛔ Aborting tunnel reuse. If you're reinstalling, try:"
    echo "   ./cloudflare/tools/cloudflare-tunnel-teardown.sh"
    exit 1
  }
else
  echo "🚧 Creating new tunnel: $TUNNEL_NAME"
  if ! cloudflared tunnel create "$TUNNEL_NAME"; then
    echo "❌ Failed to create tunnel."
    echo "   If this tunnel was used previously, try running:"
    echo "   cloudflared tunnel cleanup <uuid>"
    echo "   or the cloudflare-tunnel-teardown.sh script"
    exit 1
  fi
fi

# === Step 4: Retrieve tunnel UUID and credentials ===
TUNNEL_UUID=$(cloudflared tunnel list | awk -v name="$TUNNEL_NAME" '$2 == name { print $1 }')
CREDENTIAL_FILE="$CONFIG_SRC_DIR/$TUNNEL_UUID.json"

if [[ -z "$TUNNEL_UUID" || ! -f "$CREDENTIAL_FILE" ]]; then
  echo "❌ Missing credentials for tunnel: $TUNNEL_NAME"
  echo "   Expected: $CREDENTIAL_FILE"
  exit 1
fi

# === Step 5: Validate port availability ===
if ss -tuln | grep -q ":$FOUNDRY_PORT "; then
  echo "❌ Port $FOUNDRY_PORT is already in use."
  echo "   Check if Foundry is already running or stop a container."
  echo "   If reinstalling, run: ./cloudflare/tools/cloudflare-tunnel-teardown.sh"
  exit 1
fi

# === Step 6: Write config.yml ===
safe_mkdir "$CONFIG_DEST_DIR" || exit 1
confirm_overwrite "$CONFIG_FILE" || exit 1

echo "📄 Writing config to: $CONFIG_FILE"
sudo tee "$CONFIG_FILE" > /dev/null <<EOF
tunnel: $TUNNEL_UUID
credentials-file: $CREDENTIAL_FILE

ingress:
  - hostname: $TUNNEL_HOSTNAME
    service: http://localhost:$FOUNDRY_PORT
  - service: http_status:404
EOF

# === Step 7: Create DNS route ===
echo "🌐 Creating DNS route: $TUNNEL_HOSTNAME → $TUNNEL_UUID.cfargotunnel.com"
if ! cloudflared tunnel route dns "$TUNNEL_NAME" "$TUNNEL_HOSTNAME"; then
  echo "❌ DNS route failed. A conflicting DNS entry may exist."
  echo "   Visit your Cloudflare dashboard to remove it, then try again."
  exit 1
fi

# === Step 8: Enable and start systemd ===
if [[ "$ENABLE_TUNNEL_SERVICE" == "true" ]]; then
  echo "🛠️ Installing cloudflared as a systemd service..."
  sudo cloudflared --config "$CONFIG_FILE" --origincert "$CLOUDFLARE_CERT_PATH" service install
  sudo systemctl enable cloudflared
  sudo systemctl restart cloudflared

  sleep 2
  if systemctl is-active --quiet cloudflared; then
    echo "✅ Tunnel is active and running via systemd"
  else
    echo "❌ Tunnel service failed. View logs with:"
    echo "   journalctl -u cloudflared"
    exit 1
  fi
else
  echo "ℹ️ Skipping systemd install. To run manually:"
  echo "   cloudflared tunnel run $TUNNEL_NAME"
fi

# === Final Output ===
echo ""
echo "🎉 Cloudflare tunnel setup complete!"
echo "🔗 Access Foundry: https://$TUNNEL_HOSTNAME"
echo "🧪 Check DNS: ${DNS_PROPAGATION_CHECK_URL:-https://www.whatsmydns.net/#A/}$TUNNEL_HOSTNAME"