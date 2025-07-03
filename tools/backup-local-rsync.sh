#!/bin/bash
# tools/backup-local-rsync.sh - Incremental local backup with hard links

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
load_helpers "file-utils.sh" "tool-utils.sh"

TODAY=$(date +%F)
YESTERDAY=$(date -d "yesterday" +%F)
TODAY_DIR="$RSYNC_BACKUP_DIR/$TODAY"
YESTERDAY_DIR="$RSYNC_BACKUP_DIR/$YESTERDAY"
LOG_FILE="$FOUNDRY_BACKUP_LOG_DIR/rsync-backup-$TODAY.log"

safe_mkdir "$FOUNDRY_BACKUP_LOG_DIR"

log() {
  echo "$(date '+%F %T') | $*" | tee -a "$LOG_FILE"
}

log "📦 Starting rsync local backup"
log "📂 Source: $FOUNDRY_BACKUP_SOURCE"
log "📁 Target: $TODAY_DIR"
log "📝 Log file: $LOG_FILE"
log "---------------------------------------------"

check_tool rsync || exit 1
safe_mkdir "$RSYNC_BACKUP_DIR" || exit 1
check_disk_space "$RSYNC_BACKUP_DIR" "$MIN_DISK_MB_REQUIRED" || exit 1

# === Exclude File ===
EXCLUDE_FILE=$(get_backup_excludes rsync)
[[ -z "$EXCLUDE_FILE" ]] && log "⚠️ No exclude file generated. Continuing with full backup."

mkdir -p "$TODAY_DIR"

if [[ -d "$YESTERDAY_DIR" ]]; then
  LINK_DEST="--link-dest=$YESTERDAY_DIR"
  log "🔗 Using hard links from: $YESTERDAY_DIR"
else
  LINK_DEST=""
  log "ℹ️ No previous backup found. Full copy will be made."
fi

rsync -a \
  --delete \
  ${EXCLUDE_FILE:+--exclude-from="$EXCLUDE_FILE"} \
  $LINK_DEST \
  "$FOUNDRY_BACKUP_SOURCE/" "$TODAY_DIR/" >> "$LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
  log "✅ Backup completed successfully."
else
  log "❌ rsync returned an error. Check log for details."
  exit 1
fi

# === Rotate Old Backups ===
log "🧹 Rotating backups. Keeping last $BACKUP_RETAIN_COUNT_LOCAL..."
cd "$RSYNC_BACKUP_DIR" || exit 1
ls -1d */ | sort | head -n -"$BACKUP_RETAIN_COUNT_LOCAL" | while read -r OLD; do
  log "🗑️  Removing old backup: $OLD"
  rm -rf "$OLD"
done

log "✅ Local incremental backup saved to: $TODAY_DIR"
log "📊 Backup size: $(du -sh "$TODAY_DIR" | cut -f1)"
log "==========================================="