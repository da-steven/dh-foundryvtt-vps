#!/bin/bash
# tools/backup-remote-b2-rclone.sh - Remote backup to Backblaze B2

# Find and source load-env.sh
if [[ -f "utils/load-env.sh" ]]; then
  source "utils/load-env.sh"           
elif [[ -f "../utils/load-env.sh" ]]; then
  source "../utils/load-env.sh"       
else
  echo "❌ Cannot find utils/load-env.sh" >&2
  exit 1
fi

# Load unified configuration and additional helpers
helpers=(
  "$UTILS_DIR/foundry-config.sh"
  "$UTILS_DIR/file-utils.sh"
)

for helper in "${helpers[@]}"; do
  [[ -f "$helper" ]] && source "$helper" || {
    echo "❌ Missing required helper: $helper"
    exit 1
  }
done

# === Configuration ===
DEST_REMOTE="b2:$B2_BUCKET_NAME"
LOG_FILE="$FOUNDRY_BACKUP_LOG_DIR/b2-backup-log-$(date +%F).txt"

# === Setup logging ===
safe_mkdir "$FOUNDRY_BACKUP_LOG_DIR" || exit 1

log() {
  echo "$(date '+%F %T') | $*" | tee -a "$LOG_FILE"
}

log "📦 Starting B2 backup: $FOUNDRY_BACKUP_SOURCE → $DEST_REMOTE"
log "📝 Logging to: $LOG_FILE"
log "---------------------------------------------"

# === Pre-flight checks ===
if ! command -v rclone &>/dev/null; then
  log "❌ rclone is not installed. Aborting."
  exit 1
fi

if [[ -z "$B2_BUCKET_NAME" ]]; then
  log "❌ B2_BUCKET_NAME not set. Check your .env configuration."
  exit 1
fi

if [[ ! -d "$FOUNDRY_BACKUP_SOURCE" ]]; then
  log "❌ Source directory not found: $FOUNDRY_BACKUP_SOURCE"
  exit 1
fi

# === Run backup ===
rclone copy "$FOUNDRY_BACKUP_SOURCE" "$DEST_REMOTE" \
  --transfers=8 \
  --checkers=4 \
  --fast-list \
  --log-level INFO \
  --log-file="$LOG_FILE"

STATUS=$?

if [[ $STATUS -eq 0 ]]; then
  log "✅ B2 backup completed successfully."
else
  log "❌ B2 backup failed with exit code: $STATUS"
  exit $STATUS
fi

log "============================================="