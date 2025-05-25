#!/bin/bash
# === restic-utils.sh ===
# Shared helpers for all Restic operations

# === Load ENV ===
source "$(dirname "${BASH_SOURCE[0]}")/load-env.sh"

# === Load ENV values ===
RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE}"
RESTIC_REPO="${RESTIC_REPO}"
BACKUP_LOG_DIR="${BACKUP_LOG_DIR:-$HOME/FoundryVTT-Backups/logs}"

# === Ensure log directory exists ===
mkdir -p "$BACKUP_LOG_DIR"

# === Logging helper ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Check if the password file exists and is safe ===
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

# === Resolve repo path ===
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

# === Check if the repository is valid ===
restic_repo_check() {
  check_restic_password_file || return 1
  restic --repo "$RESTIC_REPO" --password-file "$RESTIC_PASSWORD_FILE" snapshots &>/dev/null
  if [[ $? -ne 0 ]]; then
    log "❌ Repository at $RESTIC_REPO is not valid or not initialized."
    return 1
  fi
  log "✅ Restic repository is valid: $RESTIC_REPO"
  return 0
}

# === Initialize the repository if not already done ===
init_restic_repo() {
  check_restic_password_file || return 1
  if restic_repo_check; then
    log "ℹ️ Repository already initialized."
    return 0
  fi
  log "📦 Initializing restic repo at: $RESTIC_REPO"
  restic init --repo "$RESTIC_REPO" --password-file "$RESTIC_PASSWORD_FILE"
}

# === Log restic result ===
log_restic_result() {
  if [[ "$1" -eq 0 ]]; then
    log "✅ Restic command succeeded."
  else
    log "❌ Restic command failed with exit code: $1"
  fi
}