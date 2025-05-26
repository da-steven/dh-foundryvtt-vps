#!/bin/bash

# === Config ===
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

BACKUP_SOURCE="${FOUNDRY_DATA_DIR%/}/foundry-${FOUNDRY_TAG}/Data"
BACKUP_BASE="${FOUNDRY_BACKUP_DIR%/}/rsync-backups"
EXCLUDE_FILE="$SCRIPT_DIR/.rsync-exclude.txt"
LOG_FILE="${BACKUP_LOG_DIR%/}/rsync-backup-$(date +%F).log"

TODAY=$(date +%F)
YESTERDAY=$(date -d "yesterday" +%F)
TODAY_DIR="$BACKUP_BASE/$TODAY"
YESTERDAY_DIR="$BACKUP_BASE/$YESTERDAY"

safe_mkdir "$BACKUP_BASE" || exit 1
safe_mkdir "$BACKUP_LOG_DIR" || exit 1

log() {
  echo "$(date '+%F %T') | $*" | tee -a "$LOG_FILE"
}

log "📦 Starting rsync local backup"
log "📁 Source: $BACKUP_SOURCE"
log "📂 Target: $TODAY_DIR"
log "🧾 Exclude file: $EXCLUDE_FILE"
log "📝 Log: $LOG_FILE"
log "-------------------------------------------"

if ! command -v rsync &>/dev/null; then
  log "❌ rsync not found. Aborting."
  exit 1
fi

if [[ ! -d "$BACKUP_SOURCE" ]]; then
  log "❌ Backup source not found: $BACKUP_SOURCE"
  exit 1
fi

check_disk_space "$BACKUP_BASE" 1000 || {
  log "❌ Not enough disk space. Aborting."
  exit 1
}

safe_mkdir "$TODAY_DIR" || exit 1

if [[ -d "$YESTERDAY_DIR" ]]; then
  LINK_DEST="--link-dest=$YESTERDAY_DIR"
  log "🔗 Using hard links from: $YESTERDAY_DIR"
else
  LINK_DEST=""
  log "ℹ️ No previous backup found. Full copy will be made."
fi

rsync -a \
  --delete \
  --exclude-from="$EXCLUDE_FILE" \
  $LINK_DEST \
  "$BACKUP_SOURCE/" "$TODAY_DIR/" >> "$LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
  log "✅ Backup completed successfully."
else
  log "❌ rsync returned an error. Check log for details."
  exit 1
fi

log "🧹 Rotating backups. Keeping last ${BACKUP_RETAIN_COUNT_LOCAL}..."

cd "$BACKUP_BASE" || exit 1
ls -1d */ | sort | head -n -"${BACKUP_RETAIN_COUNT_LOCAL}" | while read -r OLD; do
  log "🗑️  Removing old backup: $OLD"
  rm -rf "$OLD"
done

log "✅ Done. Local incremental backup saved to $TODAY_DIR"
log "==========================================="