#!/bin/bash

# === Bootstrap ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/../utils"

# Load helpers
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"
RESTIC_UTILS="$UTILS_DIR/restic-utils.sh"

for helper in "$ENV_LOADER" "$FILE_UTILS" "$RESTIC_UTILS"; do
  if [[ -f "$helper" ]]; then
    source "$helper"
  else
    echo "❌ Missing required helper: $helper"
    exit 1
  fi
done

# === Variables from .env ===
SOURCE_DIR="${FOUNDRY_DATA_DIR%/}/foundry-${FOUNDRY_TAG}/Data"
RESTIC_REPO="$RESTIC_REPO_DIR"
PASSWORD_FILE="$RESTIC_PASSWORD_FILE"
LOG_FILE="${BACKUP_LOG_DIR%/}/restic-backup-$(date +%Y-%m-%d).log"

# === Logging Function ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Start Log Entry ===
safe_mkdir "$BACKUP_LOG_DIR"
log "📦 Starting Restic backup"
log "📁 Source: $SOURCE_DIR"
log "📂 Repo:   $RESTIC_REPO"
log "📝 Log:    $LOG_FILE"
log "-------------------------------------------"

# === Safety Checks ===
if ! command -v restic >/dev/null 2>&1; then
  log "❌ restic is not installed. Aborting."
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  log "❌ Source directory does not exist: $SOURCE_DIR"
  exit 1
fi

if [[ ! -f "$PASSWORD_FILE" ]]; then
  log "❌ Password file not found: $PASSWORD_FILE"
  exit 1
fi

if [[ ! -s "$PASSWORD_FILE" ]]; then
  log "❌ Password file is empty: $PASSWORD_FILE"
  exit 1
fi

check_disk_space "$RESTIC_REPO" 1000 || {
  log "❌ Not enough disk space available in $RESTIC_REPO"
  exit 1
}

restic_repo_check "$RESTIC_REPO" "$PASSWORD_FILE" || {
  log "❌ Repo is not valid: $RESTIC_REPO"
  exit 1
}

# === Run Backup ===
log "▶️  Running backup..."
restic backup "$SOURCE_DIR" \
  --repo "$RESTIC_REPO" \
  --password-file "$PASSWORD_FILE" \
  --tag "foundry-${FOUNDRY_TAG}" \
  --verbose >> "$LOG_FILE" 2>&1

STATUS=$?
log_restic_result "$STATUS" "backup"
exit "$STATUS"