#!/bin/bash
# === restic-utils.sh ===
# Shared helpers for all Restic operations

# Load envs if not already loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$SCRIPT_DIR/.env.defaults" ]] && source "$SCRIPT_DIR/.env.defaults"
[[ -f "$SCRIPT_DIR/.env.local" ]] && source "$SCRIPT_DIR/.env.local"

RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE}"
RESTIC_REPO="${RESTIC_REPO}"

# Logging setup
LOG_DIR="${RESTIC_LOG_DIR:-$FOUNDRY_BACKUP_DIR/logs}"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_FILE:-$LOG_DIR/restic-generic.log}"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# Check if the password file exists and is safe
check_restic_password_file() {
  if [[ ! -f "$RESTIC_PASSWORD_FILE" ]]; then
    log "❌ Password file not found: $RESTIC_PASSWORD_FILE"
    return 1
  fi

  perms=$(stat -c "%a" "$RESTIC_PASSWORD_FILE")
  if [[ "$perms" != "600" ]]; then
    log "⚠️ Password file permissions should be 600. Current: $perms"
  fi

  return 0
}

# === get_restic_repo_path ===
# Resolves repo path via RESTIC_REPOSITORY_FILE or fallback to RESTIC_REPO
get_restic_repo_path() {
  if [[ -n "$RESTIC_REPOSITORY_FILE" ]]; then
    if [[ -s "$RESTIC_REPOSITORY_FILE" ]]; then
      local repo
      repo="$(<"$RESTIC_REPOSITORY_FILE")"
      echo "$repo"
    else
      echo "⚠️  Warning: RESTIC_REPOSITORY_FILE is defined but missing or empty: $RESTIC_REPOSITORY_FILE" >&2
      [[ -n "$RESTIC_REPO" ]] && echo "$RESTIC_REPO"
    fi
  else
    echo "$RESTIC_REPO"
  fi
}

# Check if the repository is valid
restic_repo_check() {
  check_restic_password_file || return 1
  local repo_path
  repo_path="$(get_restic_repo_path)"
  restic --repo "$repo_path" --password-file "$RESTIC_PASSWORD_FILE" snapshots &>/dev/null
  if [[ $? -ne 0 ]]; then
    log "❌ Repository at $repo_path is not valid or not initialized."
    return 1
  fi
  log "✅ Restic repository is valid: $repo_path"
  return 0
}

# Initialize the repository if not already done
init_restic_repo() {
  check_restic_password_file || return 1
  local repo_path
  repo_path="$(get_restic_repo_path)"
  if restic_repo_check; then
    log "ℹ️ Repository already initialized."
    return 0
  fi
  log "📦 Initializing restic repo at: $repo_path"
  restic init --repo "$repo_path" --password-file "$RESTIC_PASSWORD_FILE"
}

# Log summary after a restic operation
log_restic_result() {
  if [[ "$1" -eq 0 ]]; then
    log "✅ Restic command succeeded."
  else
    log "❌ Restic command failed with exit code: $1"
  fi
}