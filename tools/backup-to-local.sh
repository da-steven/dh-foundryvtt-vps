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

# === Configuration from ENV ===
TAG=$(echo "$FOUNDRY_TAG" | tr -cd '[:alnum:]-')
TAG_SUFFIX=${TAG:+-$TAG}

BACKUP_SOURCE="${FOUNDRY_DATA_DIR%/}/foundry$TAG_SUFFIX/Data"
BACKUP_BASE="${FOUNDRY_BACKUP_DIR%/}/foundry$TAG_SUFFIX"
EXCLUDE_FILE="$SCRIPT_DIR/.rsync-exclude.txt"
LOG_DIR="${LOG_DIR:-$HOME/logs}"
LOG_FILE="$LOG_DIR/local-backup-$(date +%Y-%m-%d).log"
RETAIN_COUNT="${BACKUP_RETAIN_COUNT_LOCAL:-14}"
REQUIRED_MB=1000

# === Date Directories ===
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)
TODAY_DIR="$BACKUP_BASE/$TODAY"
YESTERDAY_DIR="$BACKUP_BASE/$YESTERDAY"

# === Prepare Directories ===
safe_mkdir "$LOG_DIR" || exit 1
safe_mkdir "$BACKUP_BASE" || exit 1
check_disk_space "$BACKUP_BASE" "$REQUIRED_MB" || {
  echo "❌ Not enough disk space for backup. Aborting."
  exit 1
}
sudo chown -R "$USER:$USER" "$BACKUP_BASE" "$LOG_DIR"

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
if ! command -v rsync &>/dev/null; then
  log "❌ rsync not found. Aborting."
  exit 1
fi

if [[ ! -d "$BACKUP_SOURCE" ]]; then
  log "❌ Backup source not found: $BACKUP_SOURCE"
  exit 1
fi

AVAILABLE_MB=$(df -Pm "$BACKUP_BASE" | awk 'NR==2 {print $4}')
if (( AVAILABLE_MB < REQUIRED_MB )); then
  log "❌ Only ${AVAILABLE_MB}MB free. Minimum required: ${REQUIRED_MB}MB"
  exit 1
fi

# === Perform Backup ===
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
  --exclude-from="$EXCLUDE_FILE" \
  $LINK_DEST \
  "$BACKUP_SOURCE/" "$TODAY_DIR/" >> "$LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
  log "✅ Backup completed successfully."
else
  log "❌ rsync returned an error. Check log for details."
  exit 1
fi

# === Retention Rotation ===
log "🧹 Rotating backups. Keeping last $RETAIN_COUNT..."
cd "$BACKUP_BASE" || exit 1
ls -1d */ | sort | head -n -"$RETAIN_COUNT" | while read -r OLD; do
  log "🗑️  Removing old backup: $OLD"
  rm -rf "$OLD"
done

log "✅ Done. Local incremental backup saved to $TODAY_DIR"
log "==========================================="