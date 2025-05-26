#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
source "$UTILS_DIR/load-env.sh"
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"

for helper in "$ENV_LOADER" "$FILE_UTILS"; do
  [[ -f "$helper" ]] && source "$helper" || {
    echo "❌ Missing required helper: $helper"
    exit 1
  }
done

SOURCE_DIR="${FOUNDRY_DATA_DIR%/}/foundry-${FOUNDRY_TAG}/Data"
DEST_REMOTE="b2:$B2_BUCKET_NAME"
LOG_FILE="$BACKUP_LOG_DIR/b2-backup-log-$(date +%F).txt"

safe_mkdir "$BACKUP_LOG_DIR" || exit 1

log() {
  echo "$(date '+%F %T') | $*" | tee -a "$LOG_FILE"
}

log "📦 Starting backup: $SOURCE_DIR → $DEST_REMOTE"
log "📝 Logging to: $LOG_FILE"
log "---------------------------------------------"

if ! command -v rclone &>/dev/null; then
  log "❌ rclone is not installed. Aborting."
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  log "❌ Source directory not found: $SOURCE_DIR"
  exit 1
fi

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