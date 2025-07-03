#!/bin/bash
# tools/backup-local-restic.sh - Local incremental backup using Restic

# === Bootstrap ===
if [[ -f "utils/load-env.sh" ]]; then
  source "utils/load-env.sh"
elif [[ -f "../utils/load-env.sh" ]]; then
  source "../utils/load-env.sh"
else
  echo "❌ Cannot find utils/load-env.sh"
  exit 1
fi

# Load helpers
load_helpers "file-utils.sh" "restic-utils.sh" "tool-utils.sh"

LOG_FILE="$FOUNDRY_BACKUP_LOG_DIR/restic-backup-$(date +%F).log"
safe_mkdir "$FOUNDRY_BACKUP_LOG_DIR"

log() {
  echo "$(date '+%F %T') | $*" | tee -a "$LOG_FILE"
}

log "📦 Starting local restic backup"
log "📂 Source: $FOUNDRY_BACKUP_SOURCE"
log "📁 Repo: $RESTIC_REPO_DIR"
log "📝 Log file: $LOG_FILE"
log "---------------------------------------------"

# === Pre-flight Checks ===
check_tool restic || exit 1
check_restic_password_file || exit 1
safe_mkdir "$RESTIC_REPO_DIR" || exit 1
check_disk_space "$RESTIC_REPO_DIR" "$MIN_DISK_MB_REQUIRED" || exit 1

# Validate restic environment and repository
validate_restic_env || exit 1
restic_repo_check || {
  log "🧪 Repository missing. Attempting to initialize..."
  init_restic_repo || exit 1
}

# === Exclude File ===
EXCLUDE_FILE=$(get_backup_excludes restic)
[[ -z "$EXCLUDE_FILE" ]] && log "⚠️ No exclude file generated. Continuing with full backup."

# === Run Backup ===
restic backup "$FOUNDRY_BACKUP_SOURCE" \
  --repo "$RESTIC_REPO_DIR" \
  --password-file "$RESTIC_PASSWORD_FILE" \
  --verbose \
  ${EXCLUDE_FILE:+--exclude-file "$EXCLUDE_FILE"}

RESULT=$?
log_restic_result "$RESULT"

[[ $RESULT -ne 0 ]] && exit $RESULT

log "✅ Backup completed successfully."
log "============================================="