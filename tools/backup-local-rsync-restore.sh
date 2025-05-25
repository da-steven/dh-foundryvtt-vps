#!/bin/bash

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

BACKUP_BASE="${FOUNDRY_BACKUP_DIR%/}/rsync-backups"
RESTORE_TARGET="${FOUNDRY_DATA_DIR%/}/foundry-${FOUNDRY_TAG}/Data"
LOG_FILE="$BACKUP_LOG_DIR/restore-log-$(date +%F).txt"

safe_mkdir "$BACKUP_LOG_DIR" || exit 1

log() {
  echo "$(date '+%F %T') | $*" | tee -a "$LOG_FILE"
}

# Parse CLI flags
for arg in "$@"; do
  case $arg in
    --from=*)
      RESTORE_DATE="${arg#*=}"
      ;;
    *)
      log "❌ Unknown argument: $arg"
      exit 1
      ;;
  esac
done

# Determine backup directory
if [[ -n "$RESTORE_DATE" ]]; then
  BACKUP_DIR="$BACKUP_BASE/$RESTORE_DATE"
else
  BACKUP_DIR=$(ls -1d "$BACKUP_BASE"/*/ 2>/dev/null | sort | tail -n 1 | sed 's:/*$::')
  RESTORE_DATE=$(basename "$BACKUP_DIR")
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
  log "❌ Backup not found: $BACKUP_DIR"
  exit 1
fi

log "📦 Restoring from backup: $BACKUP_DIR"
log "📂 Target data directory: $RESTORE_TARGET"
log "📝 Log file: $LOG_FILE"

read -p "Are you sure you want to restore this backup to $RESTORE_TARGET? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && {
  log "❌ Aborted by user."
  exit 1
}

BACKUP_COPY_DIR="$RESTORE_TARGET.backup-before-restore-$(date +%F-%H%M)"
if [[ -d "$RESTORE_TARGET" && "$(ls -A "$RESTORE_TARGET")" ]]; then
  read -p "Do you want to back up the current data before restoring? (y/n): " BACKUP_CONFIRM
  if [[ "$BACKUP_CONFIRM" =~ ^[Yy]$ ]]; then
    log "🗂️  Backing up current data to: $BACKUP_COPY_DIR"
    cp -a "$RESTORE_TARGET" "$BACKUP_COPY_DIR"
  fi
fi

log "♻️  Restoring backup..."
rsync -a --delete "$BACKUP_DIR/" "$RESTORE_TARGET/" >> "$LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
  log "✅ Restore complete."
  if [[ -d "$BACKUP_COPY_DIR" ]]; then
    log "🧾 If you're satisfied with the restored data, remove:"
    log "   rm -rf \"$BACKUP_COPY_DIR\""
  fi
else
  log "❌ Restore failed. Check log: $LOG_FILE"
  exit 1
fi

log "============================================="