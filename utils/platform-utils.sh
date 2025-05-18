#!/bin/bash
# platform-utils.sh — architecture-aware download helpers

# === Detect platform architecture ===
# Outputs: amd64, arm64
detect_architecture() {
  local raw_arch
  raw_arch=$(uname -m)

  case "$raw_arch" in
    x86_64)   echo "amd64" ;;
    aarch64)  echo "arm64" ;;
    arm64)    echo "arm64" ;;
    *)
      echo "❌ Unsupported architecture: $raw_arch" >&2
      return 1
      ;;
  esac
}

# === Download binary based on detected architecture ===
# Usage: download_binary_for_arch <base_url> <filename> <dest_path>
# Example: download_binary_for_arch https://.../cloudflared-linux- cloudflared /usr/local/bin/cloudflared
download_binary_for_arch() {
  local base_url="$1"
  local binary_name="$2"
  local dest_path="$3"

  local arch
  arch=$(detect_architecture) || return 1
  local url="${base_url}${arch}"

  echo "⬇️  Downloading $binary_name ($arch)..."
  curl -fsSL "$url" -o "$binary_name" && chmod +x "$binary_name" || {
    echo "❌ Failed to download $binary_name from $url"
    return 1
  }

  echo "📦 Installing to $dest_path"
  sudo mv "$binary_name" "$dest_path" || {
    echo "❌ Failed to move binary to $dest_path"
    return 1
  }

  echo "✅ $binary_name installed at $dest_path"
  return 0
}