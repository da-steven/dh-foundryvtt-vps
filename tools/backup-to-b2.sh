#!/bin/bash

# === Bootstrap Environment ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/../utils"
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"

for helper in "$ENV_LOADER" "$FILE_UTILS"; do
  [[ -f "$helper" ]] && source "$helper" || {
    echo "❌ Missing required helper: $helper"
    exit 1
  }
done

# === Config from ENV ===
TAG=$(echo "$FOUNDRY_TAG" | tr -cd '[:alnum:]-')
TAG_SUFFIX=${TAG:+-$TAG}
SOURCE_DIR="${FOUNDRY_DATA_DIR%/}/foundry$TAG_SUFFIX/Data"
DEST_REMOTE="b2:$B2_BUCKET_NAME"
ARCHIVE_REMOTE="b2:$B2_BUCKET_NAME/archive/$(date +%Y-%m-%d)"
LOG_FILE="${LOG_DIR%/}/b2-backup-log-$(date +%Y-%m-%d).txt"

mkdir -p "$(dirname "$LOG_FILE")"

# === Logging ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Start Log Entry ===
log "📦 Starting backup: $SOURCE_DIR → $DEST_REMOTE"
log "🗂️  Archive dir for changed/deleted: $ARCHIVE_REMOTE"
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