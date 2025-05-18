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
  local version="$1"         # e.g. v0.11.2
  local base_name="$2"       # e.g. buildx
  local dest="$3"            # e.g. ~/.docker/cli-plugins/docker-buildx

  local arch=$(uname -m)
  case "$arch" in
    x86_64) arch_dl="amd64" ;;
    aarch64 | arm64) arch_dl="arm64" ;;
    *) echo "❌ Unsupported architecture: $arch" && return 1 ;;
  esac

  local filename="${base_name}-${version}.linux-${arch_dl}"
  local url="https://github.com/docker/${base_name}/releases/download/${version}/${filename}"

  echo "⬇️  Downloading $filename..."
  curl -fsSL "$url" -o "$filename" || {
    echo "❌ Failed to download $filename from $url"
    return 1
  }

  chmod +x "$filename"
  sudo mv "$filename" "$dest"
  echo "✅ Installed $base_name → $dest"
}