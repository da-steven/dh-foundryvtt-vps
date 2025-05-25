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
BACKUP_BASE="${FOUNDRY_BACKUP_DIR%/}/foundry$TAG_SUFFIX"
RESTORE_TARGET="${FOUNDRY_DATA_DIR%/}/foundry$TAG_SUFFIX/Data"
LOG_FILE="${LOG_DIR%/}/restore-log-$(date +%Y-%m-%d).txt"

mkdir -p "$(dirname "$LOG_FILE")"

# === Logging ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Parse Flags ===
DRY_RUN=false
RESTORE_DATE=""
SHOW_LIST=false

for arg in "$@"; do
  case $arg in
    --from=*)
      RESTORE_DATE="${arg#*=}"
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --list)
      SHOW_LIST=true
      ;;
    *)
      log "❌ Unknown argument: $arg"
      exit 1
      ;;
  esac
done

# === Show Available Backups ===
if [[ "$SHOW_LIST" == true ]]; then
  echo -e "\n📦 Available backups in: $BACKUP_BASE"
  ls -1d "$BACKUP_BASE"/*/ 2>/dev/null | sed 's:/*$::' | xargs -n1 basename
  echo ""
  exit 0
fi

# === Choose Backup Source ===
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

# === Confirm Intent ===
read -p "Are you sure you want to restore this backup to $RESTORE_TARGET? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && {
  log "❌ Aborted by user."
  exit 1
}

# === Offer Backup of Current Data ===
BACKUP_COPY_DIR="$RESTORE_TARGET.backup-before-restore-$(date +%Y-%m-%d-%H%M)"
if [[ -d "$RESTORE_TARGET" && "$(ls -A "$RESTORE_TARGET")" ]]; then
  read -p "Do you want to back up the current data before restoring? (y/n): " BACKUP_CONFIRM
  if [[ "$BACKUP_CONFIRM" =~ ^[Yy]$ ]]; then
    log "🗂️  Backing up current data to: $BACKUP_COPY_DIR"
    cp -a "$RESTORE_TARGET" "$BACKUP_COPY_DIR"
  fi
fi

# === Restore ===
if [[ "$DRY_RUN" == true ]]; then
  log "🔍 Running dry-run (no files changed)..."
  rsync -a --delete --dry-run "$BACKUP_DIR/" "$RESTORE_TARGET/" >> "$LOG_FILE" 2>&1
  log "✅ Dry-run complete. No files were modified."
  exit 0
else
  log "♻️  Restoring backup..."
  rsync -a --delete "$BACKUP_DIR/" "$RESTORE_TARGET/" >> "$LOG_FILE" 2>&1
fi

if [[ $? -eq 0 ]]; then
  log "✅ Restore complete."
  if [[ -d "$BACKUP_COPY_DIR" ]]; then
    log "🧾 If you're satisfied with the restored data, you can remove the previous copy:"
    log "   rm -rf \"$BACKUP_COPY_DIR\""
  fi
else
  log "❌ Restore failed. Check log: $LOG_FILE"
  exit 1
fi

log "============================================="