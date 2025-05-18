#!/bin/bash
#
# Utility functions for safely managing file and folder operations,
# including safe creation, overwrite prompts, backup copies, and disk space checks.

# === Create a directory if it doesn't exist ===
safe_mkdir() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    echo "✅ Directory already exists: $dir"
  else
    echo "📁 Creating directory: $dir"
    sudo mkdir -p "$dir" || {
      echo "❌ Failed to create: $dir"
      return 1
    }
  fi
}

# === Confirm before overwriting a file or folder ===
confirm_overwrite() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "⚠️ $path already exists."
    read -p "Do you want to overwrite it? (y/n): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
      echo "⛔ Skipping overwrite of $path"
      return 1
    fi
  fi
  return 0
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

# === Check available disk space (in MB) at given path ===
check_disk_space() {
  local path="$1"
  local required_mb="$2"
  local available_mb
  available_mb=$(df --output=avail -m "$path" | tail -1)

  if [[ "$available_mb" -lt "$required_mb" ]]; then
    echo "❌ Not enough disk space at $path. Required: ${required_mb}MB, Available: ${available_mb}MB"
    return 1
  fi
  return 0
}

# === Backup a Foundry data folder into backup_root with a timestamp ===
backup_data_folder() {
  local source="$1"
  local backup_root="$2"

  if [[ ! -d "$source" ]]; then
    echo "❌ Source data folder not found: $source"
    return 1
  fi

  local timestamp
  timestamp=$(date +"%Y-%m-%d_%H%M")
  local base_name
  base_name=$(basename "$source")
  local dest="$backup_root/${base_name}-backup-$timestamp"

  echo "📦 Backing up $source → $dest"
  sudo mkdir -p "$backup_root"

  sudo cp -r "$source" "$dest" || {
    echo "❌ Failed to copy."
    return 1
  }

  echo "✅ Backup complete: $dest"
}