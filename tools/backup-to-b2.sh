#!/bin/bash

# === Config ===
SOURCE_DIR="$HOME/FoundryVTT-Data"
BUCKET_NAME="dh-foundry-foundry-v12"
DEST_REMOTE="b2:$BUCKET_NAME"
ARCHIVE_REMOTE="b2:$BUCKET_NAME/archive/$(date +%Y-%m-%d)"
LOG_DIR="$HOME/logs"
LOG_FILE="$LOG_DIR/backup-log.txt"

mkdir -p "$LOG_DIR"

# === Log Function ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Start Log Entry ===
log "📦 Starting backup: $SOURCE_DIR → $DEST_REMOTE"
log "🗂️  Archive dir for changed/deleted: $ARCHIVE_REMOTE"J
log "📝 Logging to: $LOG_FILE"
log "---------------------------------------------"

# === Safety Checks ===
if ! command -v rclone &>/dev/null; then
  log "❌ rclone is not installed. Aborting."
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  log "❌ Source directory not found: $SOURCE_DIR"
  exit 1
fi

# === Run Backup ===
rclone copy "$SOURCE_DIR" "$DEST_REMOTE" \
  --transfers=8 \
  --checkers=4 \
  --fast-list \
  --log-level INFO \
  --log-file="$LOG_FILE"

STATUS=$?

if [[ $STATUS -eq 0 ]]; then
  log "✅ Backup completed successfully."
else
  log "❌ Backup failed with exit code: $STATUS"
fi

log "============================================="
