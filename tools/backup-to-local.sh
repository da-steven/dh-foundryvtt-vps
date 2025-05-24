#!/bin/bash

# === Configuration ===
BACKUP_SOURCE="$HOME/FoundryVTT-Data/foundry-v12/Data"
BACKUP_BASE="$HOME/FoundryVTT-Backups/foundry-v12"
EXCLUDE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.rsync-exclude.txt"
LOG_DIR="$HOME/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/local-backup-$(date +%Y-%m-%d).log"

# How many backups to keep
BACKUP_RETAIN_COUNT=14

# Minimum free space required in MB
REQUIRED_MB=1000

# === Calculate Dates ===
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)
TODAY_DIR="$BACKUP_BASE/$TODAY"
YESTERDAY_DIR="$BACKUP_BASE/$YESTERDAY"

# === Logging Function ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

log "📦 Starting rsync local backup"
log "📁 Source: $BACKUP_SOURCE"
log "📂 Target: $TODAY_DIR"
log "🧾 Exclude file: $EXCLUDE_FILE"
log "📝 Log: $LOG_FILE"
log "-------------------------------------------"

# === Safety Checks ===

# Ensure rsync is installed
if ! command -v rsync &>/dev/null; then
  log "❌ rsync not found. Aborting."
  exit 1
fi

# Ensure source exists
if [[ ! -d "$BACKUP_SOURCE" ]]; then
  log "❌ Backup source not found: $BACKUP_SOURCE"
  exit 1
fi

# Check available disk space (in MB)
AVAILABLE_MB=$(df -Pm "$BACKUP_BASE" | awk 'NR==2 {print $4}')
if (( AVAILABLE_MB < REQUIRED_MB )); then
  log "❌ Only ${AVAILABLE_MB}MB free. Minimum required: ${REQUIRED_MB}MB"
  exit 1
fi

# === Perform Incremental Backup with Hard Links ===

mkdir -p "$TODAY_DIR"

# Use --link-dest to hard link unchanged files from yesterday's backup
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

# === Rotate Old Backups ===
log "🧹 Rotating backups. Keeping last $BACKUP_RETAIN_COUNT..."
cd "$BACKUP_BASE" || exit 1
ls -1d */ | sort | head -n -"$BACKUP_RETAIN_COUNT" | while read -r OLD; do
  log "🗑️  Removing old backup: $OLD"
  rm -rf "$OLD"
done

log "✅ Done. Local incremental backup saved to $TODAY_DIR"
log "==========================================="
