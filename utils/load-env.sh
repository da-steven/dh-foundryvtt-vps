#!/bin/bash
# utils/load-env.sh - Location-aware environment loader

# Find the repo root (where .env.defaults lives)
find_repo_root() {
  local current="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"  # Note: [1] not [0]
  
  while [[ "$current" != "/" ]]; do
    if [[ -f "$current/.env.defaults" ]]; then
      echo "$current"
      return 0
    fi
    current="$(dirname "$current")"
  done
  
  # Fallback
  echo "$current"
}

REPO_ROOT="$(find_repo_root)"

# Load environment files
if [[ -f "$REPO_ROOT/.env.defaults" ]]; then
  source "$REPO_ROOT/.env.defaults"
fi

if [[ -f "$REPO_ROOT/.env.local" ]]; then
  source "$REPO_ROOT/.env.local"
fi

# Export paths for all scripts to use
export REPO_ROOT
export UTILS_DIR="$REPO_ROOT/utils"
export TOOLS_DIR="$REPO_ROOT/tools"

# === Logging helper ===
source "$UTILS_DIR/file-utils.sh"

LOG_DIR="${LOG_DIR:-$HOME/logs}"
LOG_FILE="$LOG_DIR/general.log"
safe_mkdir "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Load shared utility functions ===
# TODO: Consider moving this to utils.sh or similar shared file
load_helpers() {

  # Check if UTILS_DIR is set
  if [[ -z "$UTILS_DIR" ]]; then
    log "❌ UTILS_DIR is not set. Cannot load helpers."
    exit 1
  fi

  # Process helpers
  local helpers=("$@")

  for name in "${helpers[@]}"; do
    local helper="$UTILS_DIR/$name"
    if [[ -f "$helper" ]]; then
      source "$helper"
    else
      log "❌ Missing required helper: $helper"
      exit 1
    fi
  done
}