#!/bin/bash
# === tool-utils.sh ===
# Shared helpers for verifying and installing required tools (restic, rclone, rsync, etc.)

# 🛠️ Auto-install flag
AUTO_INSTALL=false

# 🔍 Check if a tool is installed
check_tool() {
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    echo "✅ $tool is installed"
    return 0
  else
    echo "⚠️  $tool is not installed"
    return 1
  fi
}

# 📦 Install tool if missing, optionally auto-confirm
install_tool() {
  local tool="$1"

  if $AUTO_INSTALL; then
    echo "📦 Auto-installing $tool..."
  else
    read -rp "❓ Would you like to install $tool? (y/N): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
      echo "⏭️  Skipping installation of $tool"
      return 1
    fi
  fi

  sudo apt update && sudo apt install -y "$tool"
  echo "🔁 Verifying $tool after install..."
  check_tool "$tool" && return 0 || {
    echo "❌ Installation failed for $tool"
    return 1
  }
}

# 🧪 CLI arg parsing (only when script is executed directly)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y)
        AUTO_INSTALL=true
        shift
        ;;
      *)
        echo "Usage: $(basename "$0") [--yes|-y]" >&2
        exit 1
        ;;
    esac
  done
fi