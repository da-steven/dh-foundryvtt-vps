#!/bin/bash
# === file-utils.sh ===
# Shared filesystem utilities for Foundry VPS setup and backup scripts

# === ensure_ownership ===
# Ensures that the given path is owned by the current user and group.
ensure_ownership() {
  local target="$1"
  local uid=$(id -u)
  local gid=$(id -g)

  if [[ -z "$target" ]]; then
    echo "❌ ensure_ownership: No target path provided"
    return 1
  fi

  if [[ ! -e "$target" ]]; then
    echo "⚠️  ensure_ownership: Target does not exist: $target"
    return 1
  fi

  sudo chown -R "$uid:$gid" "$target"
}

# === safe_mkdir ===
# Creates a directory if it doesn't exist, with sudo and correct ownership.
safe_mkdir() {
  local dir="$1"

  if [[ -z "$dir" ]]; then
    echo "❌ safe_mkdir: No directory provided"
    return 1
  fi

  if [[ -d "$dir" ]]; then
    echo "✅ Directory already exists: $dir"
    return 0
  fi

  echo "📁 Creating directory: $dir"
  sudo mkdir -p "$dir"
  ensure_ownership "$dir"
}

# === Confirm before deleting a path ===
confirm_delete() {
  local target="$1"
  if [[ -e "$target" ]]; then
    echo "⚠️ $target exists."
    read -p "Do you want to delete it? (y/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
      echo "🗑️ Deleting $target..."
      sudo rm -rf "$target"
    else
      echo "⛔ Deletion cancelled."
      return 1
    fi
  fi
}

# === confirm_overwrite ===
# Prompts user to overwrite a file or directory if it exists.
confirm_overwrite() {
  local path="$1"

  if [[ -e "$path" ]]; then
    echo "⚠️  $path already exists."
    read -p "Do you want to overwrite it? (y/n): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
      echo "⛔ Aborted by user."
      return 1
    fi
  fi

  return 0
}

# === check_disk_space ===
# Checks if the given path has at least the requested number of MB free.
check_disk_space() {
  local path="$1"
  local required_mb="$2"

  if [[ ! -d "$path" ]]; then
    echo "⚠️  Disk check path does not exist. Creating: $path"
    sudo mkdir -p "$path"
    ensure_ownership "$path"
  fi

  local available_mb
  available_mb=$(df -Pm "$path" | awk 'NR==2 {print $4}')

  if (( available_mb < required_mb )); then
    echo "❌ Only ${available_mb}MB free at $path. Required: ${required_mb}MB"
    return 1
  fi

  echo "✅ Disk space OK at $path: ${available_mb}MB available"
  return 0
}

# === backup_data_folder ===
# Makes a dated copy of a folder for manual backup.
backup_data_folder() {
  local source="$1"
  local target_base="$2"

  if [[ ! -d "$source" ]]; then
    echo "❌ Source directory not found: $source"
    return 1
  fi

  local timestamp
  timestamp=$(date +%Y-%m-%d-%H%M%S)
  local dest="$target_base/backup-before-overwrite-$timestamp"

  echo "📦 Backing up $source → $dest"
  cp -a "$source" "$dest"
  ensure_ownership "$dest"
}