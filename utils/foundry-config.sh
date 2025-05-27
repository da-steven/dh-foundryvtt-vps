#!/bin/bash
# utils/foundry-config.sh - Unified Foundry configuration and path management

# Load base environment first
source "$(dirname "${BASH_SOURCE[0]}")/load-env.sh"

# Validate required base variables
validate_foundry_env() {
  local required_vars=(
    "FOUNDRY_INSTALL_DIR"
    "FOUNDRY_DATA_DIR" 
    "FOUNDRY_BACKUP_DIR"
    "FOUNDRY_PORT"
  )
  
  # Optional but commonly used variables (warn if missing)
  local optional_vars=(
    "RESTIC_REPO_DIR"
    "RESTIC_PASSWORD_FILE"
    "B2_BUCKET_NAME"
  )
  
  local missing_vars=()
  for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
      missing_vars+=("$var")
    fi
  done
  
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "❌ Missing required environment variables: ${missing_vars[*]}" >&2
    return 1
  fi
  
  # Warn about missing optional vars
  for var in "${optional_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
      echo "⚠️ Optional variable not set: $var (some backup features may not work)" >&2
    fi
  done
  
  return 0
}

# Construct and export all Foundry paths
init_foundry_paths() {
  validate_foundry_env || return 1
  
  # Handle optional FOUNDRY_TAG
  local tag_suffix=""
  if [[ -n "$FOUNDRY_TAG" ]]; then
    tag_suffix="-$FOUNDRY_TAG"
  fi
  
  # Core paths (used by setup script)
  export FOUNDRY_INSTALL_PATH="${FOUNDRY_INSTALL_DIR%/}/foundry${tag_suffix}"
  export FOUNDRY_DATA_PATH="${FOUNDRY_DATA_DIR%/}/foundry${tag_suffix}"
  export FOUNDRY_CONTAINER_NAME="foundryvtt${tag_suffix}"
  
  # Backup-specific paths
  export FOUNDRY_BACKUP_SOURCE="$FOUNDRY_DATA_PATH/Data"
  export FOUNDRY_RSYNC_BACKUP_PATH="${FOUNDRY_BACKUP_DIR%/}/rsync-backups"
  export FOUNDRY_RESTIC_REPO_PATH="$RESTIC_REPO_DIR"
  
  # Restic compatibility (export both variable names)
  export RESTIC_REPO="$RESTIC_REPO_DIR"
  
  # Log paths
  export FOUNDRY_LOG_DIR="${LOG_DIR:-$HOME/logs}"
  export FOUNDRY_BACKUP_LOG_DIR="${BACKUP_LOG_DIR:-$FOUNDRY_BACKUP_DIR/logs}"
  
  return 0
}

# Print current configuration (for debugging)
show_foundry_config() {
  echo "📋 Foundry Configuration:"
  echo "  Tag:           ${FOUNDRY_TAG:-<none>}"
  echo "  Port:          $FOUNDRY_PORT"
  echo "  Install:       $FOUNDRY_INSTALL_PATH"
  echo "  Data:          $FOUNDRY_DATA_PATH" 
  echo "  Container:     $FOUNDRY_CONTAINER_NAME"
  echo ""
  echo "📦 Backup Configuration:"
  echo "  Source:        $FOUNDRY_BACKUP_SOURCE"
  echo "  Local Backups: $FOUNDRY_BACKUP_DIR"
  echo "  Rsync Backups: $FOUNDRY_RSYNC_BACKUP_PATH"
  echo "  Restic Repo:   ${RESTIC_REPO:-<not set>}"
  echo "  B2 Bucket:     ${B2_BUCKET_NAME:-<not set>}"
  echo "  Logs:          $FOUNDRY_BACKUP_LOG_DIR"
}

# Auto-initialize when sourced (unless FOUNDRY_NO_AUTO_INIT is set)
if [[ -z "$FOUNDRY_NO_AUTO_INIT" ]]; then
  init_foundry_paths
fi