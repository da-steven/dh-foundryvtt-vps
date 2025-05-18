#!/bin/bash

# === Resolve tool paths ===
TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_PATH="$TOOL_DIR/tools"

SETUP_SCRIPT="$TOOLS_PATH/cloudflare-tunnel-setup.sh"
TEARDOWN_SCRIPT="$TOOLS_PATH/cloudflare-tunnel-teardown.sh"
STATUS_SCRIPT="$TOOLS_PATH/cloudflare-tunnel-status.sh"
VERIFY_SCRIPT="$TOOLS_PATH/cloudflare-tunnel-verify.sh"

# === Ensure scripts are executable ===
chmod +x "$SETUP_SCRIPT" "$TEARDOWN_SCRIPT" "$STATUS_SCRIPT" "$VERIFY_SCRIPT" 2>/dev/null || true

# === Menu Header ===
print_header() {
  echo ""
  echo "╭──────────────────────────────────────────────╮"
  echo "│ ⚙️  Cloudflare Tunnel Tools Menu"
  echo "╰──────────────────────────────────────────────╯"
}

# === Menu Items ===
show_menu() {
  echo ""
  echo "🛡️  Available Actions:"
  echo "---------------------------"
  echo "1) Setup Cloudflare Tunnel"
  echo "2) Teardown Cloudflare Tunnel"
  echo "3) Show Tunnel Status"
  echo "4) Verify Tunnel Connection"
  echo "5) Exit"
  echo ""
}

# === CLI Flag Support ===
if [[ "$1" =~ ^--(setup|teardown|status|verify|help)$ ]]; then
  case "$1" in
    --setup)    bash "$SETUP_SCRIPT"; exit $? ;;
    --teardown) bash "$TEARDOWN_SCRIPT"; exit $? ;;
    --status)   bash "$STATUS_SCRIPT"; exit $? ;;
    --verify)   bash "$VERIFY_SCRIPT"; exit $? ;;
    --help)
      echo ""
      echo "📘 Usage: ./cloudflare-tools.sh [OPTION]"
      echo ""
      echo "Available options:"
      echo "  --setup       Run tunnel setup"
      echo "  --teardown    Remove tunnel and configs"
      echo "  --status      Show current tunnel configuration"
      echo "  --verify      Check DNS and systemd status"
      echo "  --help        Show this help message"
      echo ""
      echo "Run without flags to open the interactive menu."
      exit 0
      ;;
  esac
fi

# === Interactive Mode ===
while true; do
  clear
  print_header
  show_menu
  read -rp "Choose an option [1-5]: " CHOICE
  echo ""

  case "$CHOICE" in
    1) bash "$SETUP_SCRIPT" ;;
    2) bash "$TEARDOWN_SCRIPT" ;;
    3) bash "$STATUS_SCRIPT" ;;
    4) bash "$VERIFY_SCRIPT" ;;
    5)
      echo "👋 Exiting Cloudflare tools."
      echo ""
      exit 0
      ;;
    *)
      echo "❓ Invalid choice. Please enter a number 1-5."
      ;;
  esac

  echo ""
  read -rp "Press Enter to return to the menu..." _
done