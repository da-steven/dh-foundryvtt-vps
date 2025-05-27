#!/bin/bash
# tools/backup-local-rsync.sh - Local incremental backups using rsync

# Find and source load-env.sh
if [[ -f "utils/load-env.sh" ]]; then
  source "utils/load-env.sh"           
elif [[ -f "../utils/load-env.sh" ]]; then
  source "../utils/load-env.sh"       
else
  echo "❌ Cannot find utils/load-env.sh" >&2
  exit 1
fi

# Load unified configuration and helpers
load_helpers \
  "foundry-config.sh" \
  "file-utils.sh" 

# === Configuration ===
EXCLUDE_FILE="$REPO_ROOT/.rsync-exclude.txt"
LOG_FILE="$FOUNDRY_BACKUP_LOG_DIR/rsync-backup-$(date +%F).log"

TODAY=$(date +%F)
YESTERDAY=$(date -d "yesterday" +%F)
TODAY_DIR="$FOUNDRY_RSYNC_BACKUP_PATH/$TODAY"
YESTERDAY_DIR="$FOUNDRY_RSYNC_BACKUP_PATH/$YESTERDAY"

# === Setup directories and logging ===
safe_mkdir "$FOUNDRY_RSYNC_BACKUP_PATH" || exit 1
safe_mkdir "$FOUNDRY_BACKUP_LOG_DIR" || exit 1

log() {
  echo "$(date '+%F %T') | $*" | tee -a "$LOG_FILE"
}

log "📦 Starting rsync local backup"
log "📁 Source: $FOUNDRY_BACKUP_SOURCE"
log "📂 Target: $TODAY_DIR"
log "🧾 Exclude file: $EXCLUDE_FILE"
log "📝 Log: $LOG_FILE"
log "-------------------------------------------"

# === Pre-flight checks ===
if ! command -v rsync &>/dev/null; then
  log "❌ rsync not found. Aborting."
  exit 1
fi

if [[ ! -d "$FOUNDRY_BACKUP_SOURCE" ]]; then
  log "❌ Backup source not found: $FOUNDRY_BACKUP_SOURCE"
  exit 1
fi

check_disk_space "$FOUNDRY_RSYNC_BACKUP_PATH" 1000 || {
  log "❌ Not enough disk space. Aborting."
  exit 1
}

# === Create today's backup directory ===
safe_mkdir "$TODAY_DIR" || exit 1

# === Determine if we can use hard links ===
if [[ -d "$YESTERDAY_DIR" ]]; then
  LINK_DEST="--link-dest=$YESTERDAY_DIR"
  log "🔗 Using hard links from: $YESTERDAY_DIR"
else
  LINK_DEST=""
  log "ℹ️ No previous backup found. Full copy will be made."
fi

# === Run the backup ===
RSYNC_OPTS="-a --delete"
if [[ -f "$EXCLUDE_FILE" ]]; then
  RSYNC_OPTS="$RSYNC_OPTS --exclude-from=$EXCLUDE_FILE"
  log "📋 Using exclude file: $EXCLUDE_FILE"
else
  log "⚠️ No exclude file found at: $EXCLUDE_FILE"
fi

rsync $RSYNC_OPTS $LINK_DEST \
  "$FOUNDRY_BACKUP_SOURCE/" "$TODAY_DIR/" >> "$LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
  log "✅ Backup completed successfully."
else
  log "❌ rsync returned an error. Check log for details."
  exit 1
fi

# === Cleanup old backups ===
log "🧹 Rotating backups. Keeping last ${BACKUP_RETAIN_COUNT_LOCAL}..."

cd "$FOUNDRY_RSYNC_BACKUP_PATH" || exit 1
ls -1d */ | sort | head -n -"${BACKUP_RETAIN_COUNT_LOCAL}" | while read -r OLD; do
  log "🗑️ Removing old backup: $OLD"
  rm -rf "$OLD"
done

log "✅ Local incremental backup saved to: $TODAY_DIR"
log "📊 Backup size: $(du -sh "$TODAY_DIR" | cut -f1)"
log "==========================================="