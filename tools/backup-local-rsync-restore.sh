#!/bin/bash
# tools/backup-local-rsync-restore.sh - Restore from rsync backup

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

# === Setup logging ===
safe_mkdir "$FOUNDRY_BACKUP_LOG_DIR" || exit 1
LOG_FILE="$FOUNDRY_BACKUP_LOG_DIR/rsync-restore-$(date +%F).log"

log() {
  echo "$(date '+%F %T') | $*" | tee -a "$LOG_FILE"
}

# === Parse command line arguments ===
RESTORE_DATE=""
DRY_RUN=false
LIST_BACKUPS=false

for arg in "$@"; do
  case $arg in
    --from=*)
      RESTORE_DATE="${arg#*=}"
      ;;
    --list)
      LIST_BACKUPS=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    *)
      echo "❌ Unknown argument: $arg"
      echo "Usage: $0 [--list] [--from=YYYY-MM-DD] [--dry-run]"
      exit 1
      ;;
  esac
done

# === List available backups if requested ===
if [[ "$LIST_BACKUPS" == true ]]; then
  echo "📋 Available rsync backups:"
  if [[ -d "$FOUNDRY_RSYNC_BACKUP_PATH" ]]; then
    ls -la "$FOUNDRY_RSYNC_BACKUP_PATH" | grep "^d" | awk '{print "  " $9 "  (" $5 " " $6 " " $7 ")"}'
  else
    echo "  No backups found at: $FOUNDRY_RSYNC_BACKUP_PATH"
  fi
  exit 0
fi

# === Determine backup directory ===
if [[ -n "$RESTORE_DATE" ]]; then
  BACKUP_DIR="$FOUNDRY_RSYNC_BACKUP_PATH/$RESTORE_DATE"
  if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "❌ Backup not found for date: $RESTORE_DATE"
    echo "   Expected: $BACKUP_DIR"
    echo "   Use --list to see available backups"
    exit 1
  fi
else
  # Find most recent backup
  BACKUP_DIR=$(ls -1d "$FOUNDRY_RSYNC_BACKUP_PATH"/*/ 2>/dev/null | sort | tail -n 1 | sed 's:/*$::')
  if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
    echo "❌ No backups found at: $FOUNDRY_RSYNC_BACKUP_PATH"
    echo "   Use --list to see available backups"
    exit 1
  fi
  RESTORE_DATE=$(basename "$BACKUP_DIR")
fi

# === Setup restore target ===
RESTORE_TARGET="$FOUNDRY_BACKUP_SOURCE"

log "♻️  Starting rsync restore operation"
log "📂 Backup: $BACKUP_DIR"
log "📁 Target: $RESTORE_TARGET"
log "📝 Log: $LOG_FILE"
log "---------------------------------------------"

# === Dry run check ===
if [[ "$DRY_RUN" == true ]]; then
  log "🧪 DRY RUN MODE - No actual restore will occur"
  echo ""
  echo "📋 Would restore backup from '$RESTORE_DATE' to: $RESTORE_TARGET"
  echo ""
  echo "📂 Backup contents (sample):"
  ls -la "$BACKUP_DIR" | head -10
  if [[ $(ls -1 "$BACKUP_DIR" | wc -l) -gt 10 ]]; then
    echo "... (showing first 10 items)"
  fi
  echo ""
  echo "📊 Backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
  exit 0
fi

# === Interactive confirmation (only if running interactively) ===
if [[ -t 0 ]]; then  # Only prompt if running interactively
  echo ""
  echo "⚠️  RESTORE CONFIRMATION"
  echo "   Backup Date: $RESTORE_DATE"
  echo "   Source:      $BACKUP_DIR"
  echo "   Target:      $RESTORE_TARGET" 
  echo "   Size:        $(du -sh "$BACKUP_DIR" | cut -f1)"
  echo ""
  echo "   This will OVERWRITE the current Foundry data!"
  echo ""
  read -p "   Continue with restore? (y/n): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log "❌ Restore cancelled by user"
    exit 1
  fi

  # Offer to backup current data
  if [[ -d "$RESTORE_TARGET" && "$(ls -A "$RESTORE_TARGET" 2>/dev/null)" ]]; then
    read -p "   Backup current data before restoring? (y/n): " BACKUP_FIRST
    if [[ "$BACKUP_FIRST" =~ ^[Yy]$ ]]; then
      BACKUP_COPY="$RESTORE_TARGET.backup-before-restore-$(date +%F-%H%M%S)"
      log "🗂️  Creating backup of current data..."
      cp -a "$RESTORE_TARGET" "$BACKUP_COPY"
      log "✅ Current data backed up to: $BACKUP_COPY"
    fi
  fi
fi

# === Create restore target directory ===
safe_mkdir "$(dirname "$RESTORE_TARGET")" || exit 1

# === Perform the restore ===
log "🔄 Restoring backup from $RESTORE_DATE..."
rsync -a --delete "$BACKUP_DIR/" "$RESTORE_TARGET/" >> "$LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
  log "✅ Rsync restore completed successfully"
  
  # Fix ownership
  ensure_ownership "$RESTORE_TARGET"
  
  echo ""
  echo "✅ Restore completed successfully!"
  echo "📁 Data restored from: $BACKUP_DIR"
  echo "📁 Data restored to: $RESTORE_TARGET"
  
  if [[ -n "$BACKUP_COPY" ]]; then
    echo "🧾 Original data backed up to: $BACKUP_COPY"
    echo "   Remove with: rm -rf \"$BACKUP_COPY\""
  fi
  
  echo ""
  echo "🔄 You may need to restart your Foundry container:"
  echo "   docker restart $FOUNDRY_CONTAINER_NAME"
  
else
  log "❌ Rsync restore failed. Check log: $LOG_FILE"
  exit 1
fi

log "============================================="