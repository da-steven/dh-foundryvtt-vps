#!/bin/bash
# tools/backup-remote-b2-rclone.sh - Remote backup to Backblaze B2

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
load_helpers "file-utils.sh" "tool-utils.sh" "send-email-mailjet.sh"

# === Configuration ===
DEST_REMOTE="b2:$B2_BUCKET_NAME"
LOG_FILE="$FOUNDRY_BACKUP_LOG_DIR/b2-backup-log-$(date +%F).txt"
safe_mkdir "$FOUNDRY_BACKUP_LOG_DIR"

log() {
  echo "$(date '+%F %T') | $*" | tee -a "$LOG_FILE"
}

log "📦 Starting B2 backup"
log "📂 Source: $FOUNDRY_BACKUP_SOURCE"
log "📁 Destination: $DEST_REMOTE"
log "📝 Log file: $LOG_FILE"
log "---------------------------------------------"

# === Pre-flight Checks ===
check_tool rclone || {
  log "❌ rclone is not installed. Aborting."
  send_email "B2 Backup Failed" "B2 backup aborted: rclone not found."
  exit 1
}

if [[ -z "$B2_BUCKET_NAME" ]]; then
  log "❌ B2_BUCKET_NAME not set. Check your .env configuration."
  send_email "B2 Backup Failed" "B2 backup aborted: B2_BUCKET_NAME not set."
  exit 1
fi

if [[ ! -d "$FOUNDRY_BACKUP_SOURCE" ]]; then
  log "❌ Source directory not found: $FOUNDRY_BACKUP_SOURCE"
  send_email "B2 Backup Failed" "B2 backup aborted: Source path not found."
  exit 1
fi

# === Exclude File ===
EXCLUDE_FILE=$(get_backup_excludes "b2")
if [[ -z "$EXCLUDE_FILE" || ! -s "$EXCLUDE_FILE" ]]; then
  log "❌ Failed to generate filtered exclude file for B2."
  send_email "B2 Backup Failed" "B2 backup aborted: exclude file missing or empty."
  exit 1
fi

log "🚀 Running B2 backup job..."
rclone copy "$FOUNDRY_BACKUP_SOURCE" "$DEST_REMOTE" \
  --exclude-from="$EXCLUDE_FILE" \
  --transfers=8 \
  --checkers=4 \
  --fast-list \
  --log-level INFO \
  --log-file="$LOG_FILE"

STATUS=$?

if [[ $STATUS -eq 0 ]]; then
  log "✅ B2 backup completed successfully."
  send_email "B2 Backup Successful" "B2 backup completed successfully on $(date)."
else
  log "❌ B2 backup failed with exit code: $STATUS"
  send_email "B2 Backup Failed" "B2 backup failed with exit code $STATUS at $(date). Check log: $LOG_FILE"
  exit $STATUS
fi

log "============================================="