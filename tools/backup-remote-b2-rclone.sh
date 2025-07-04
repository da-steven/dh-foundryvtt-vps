#!/bin/bash
# tools/backup-remote-b2-rclone.sh - Remote backup to Backblaze B2

# === Bootstrap Environment ===
if [[ -f "utils/load-env.sh" ]]; then
  source "utils/load-env.sh"
elif [[ -f "../utils/load-env.sh" ]]; then
  source "../utils/load-env.sh"
else
  echo "❌ Cannot find utils/load-env.sh" >&2
  exit 1
fi

# Load helpers
load_helpers "file-utils.sh" "tool-utils.sh" "send-email-mailjet.sh"

# === Sanity Checks ===
: "${B2_BUCKET_NAME:?B2_BUCKET_NAME not set in .env}"
: "${FOUNDRY_BACKUP_SOURCE:?FOUNDRY_BACKUP_SOURCE not set in .env}"
: "${FOUNDRY_BACKUP_LOG_DIR:?FOUNDRY_BACKUP_LOG_DIR not set in .env}"

# === Setup ===
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

# === Tool Check ===
check_tool rclone || exit 1

# === Exclude File ===
EXCLUDE_FILE=$(get_backup_excludes "b2")
if [[ -z "$EXCLUDE_FILE" || ! -s "$EXCLUDE_FILE" ]]; then
  log "❌ Failed to generate filtered exclude file for B2"
  send_email "B2 Backup Failed" \
    "B2 backup aborted: no valid exclude file generated at $(date).\nCheck your .backup-exclude.txt for formatting or path issues."
  exit 1
fi

# === Source Check ===
if [[ ! -d "$FOUNDRY_BACKUP_SOURCE" ]]; then
  log "❌ Source directory not found: $FOUNDRY_BACKUP_SOURCE"
  send_email "B2 Backup Failed" \
    "B2 backup aborted: Source directory not found: $FOUNDRY_BACKUP_SOURCE"
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
  send_email "B2 Backup Failed" \
    "B2 backup failed with exit code $STATUS at $(date).\nLog: $LOG_FILE"
  exit $STATUS
fi

log "============================================="
