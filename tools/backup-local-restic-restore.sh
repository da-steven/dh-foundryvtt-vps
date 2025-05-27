#!/bin/bash
# tools/backup-local-restic-restore.sh - Restore from restic snapshot

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
helpers=(
  "$UTILS_DIR/foundry-config.sh"
  "$UTILS_DIR/file-utils.sh"
  "$UTILS_DIR/restic-utils.sh"
)

for helper in "${helpers[@]}"; do
  [[ -f "$helper" ]] && source "$helper" || {
    echo "❌ Missing required helper: $helper"
    exit 1
  }
done

# === Setup logging ===
safe_mkdir "$FOUNDRY_BACKUP_LOG_DIR" || exit 1
LOG_FILE="$FOUNDRY_BACKUP_LOG_DIR/restic-restore-$(date +%F).log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Parse command line arguments ===
SNAPSHOT_ID=""
DRY_RUN=false
LIST_SNAPSHOTS=false

for arg in "$@"; do
  case $arg in
    --id=*) 
      SNAPSHOT_ID="${arg#*=}" 
      ;;
    --list)
      LIST_SNAPSHOTS=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    *)
      echo "❌ Unknown argument: $arg"
      echo "Usage: $0 [--list] [--id=<snapshot>] [--dry-run]"
      exit 1
      ;;
  esac
done

# === Pre-flight checks ===
validate_restic_env || exit 1
restic_repo_check || exit 1

# === List snapshots if requested ===
if [[ "$LIST_SNAPSHOTS" == true ]]; then
  echo "📋 Available snapshots:"
  restic --repo "$RESTIC_REPO" --password-file "$RESTIC_PASSWORD_FILE" snapshots
  exit 0
fi

# === Validate snapshot ID ===
if [[ -z "$SNAPSHOT_ID" ]]; then
  echo "❌ No snapshot ID provided."
  echo ""
  echo "Usage: $0 --id=<snapshot-id> [--dry-run]"
  echo "   or: $0 --list  (to see available snapshots)"
  echo ""
  echo "Example: $0 --id=latest"
  echo "Example: $0 --id=a1b2c3d4"
  exit 1
fi

# === Setup restore target ===
RESTORE_TARGET="$FOUNDRY_DATA_PATH"

log "♻️  Starting Restic restore operation"
log "📂 Repository: $RESTIC_REPO"
log "🎯 Snapshot: $SNAPSHOT_ID"
log "📁 Target: $RESTORE_TARGET"
log "📝 Log: $LOG_FILE"
log "---------------------------------------------"

# === Dry run check ===
if [[ "$DRY_RUN" == true ]]; then
  log "🧪 DRY RUN MODE - No actual restore will occur"
  echo ""
  echo "📋 Would restore snapshot '$SNAPSHOT_ID' to: $RESTORE_TARGET"
  echo ""
  echo "📂 Snapshot contents:"
  restic --repo "$RESTIC_REPO" --password-file "$RESTIC_PASSWORD_FILE" ls "$SNAPSHOT_ID" | head -20
  if [[ $(restic --repo "$RESTIC_REPO" --password-file "$RESTIC_PASSWORD_FILE" ls "$SNAPSHOT_ID" | wc -l) -gt 20 ]]; then
    echo "... (showing first 20 items, use 'restic ls $SNAPSHOT_ID' for full list)"
  fi
  exit 0
fi

# === Interactive confirmation (only if not in cron/script mode) ===
if [[ -t 0 ]]; then  # Only prompt if running interactively
  echo ""
  echo "⚠️  RESTORE CONFIRMATION"
  echo "   Snapshot: $SNAPSHOT_ID"
  echo "   Target:   $RESTORE_TARGET"
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
      BACKUP_COPY="$RESTORE_TARGET.before-restore-$(date +%Y%m%d-%H%M%S)"
      log "🗂️  Creating backup of current data..."
      cp -a "$RESTORE_TARGET" "$BACKUP_COPY"
      log "✅ Current data backed up to: $BACKUP_COPY"
    fi
  fi
fi

# === Create restore target directory ===
safe_mkdir "$(dirname "$RESTORE_TARGET")" || exit 1

# === Perform the restore ===
log "🔄 Restoring snapshot $SNAPSHOT_ID..."
restic --repo "$RESTIC_REPO" --password-file "$RESTIC_PASSWORD_FILE" \
  restore "$SNAPSHOT_ID" \
  --target "$(dirname "$RESTORE_TARGET")"

if [[ $? -eq 0 ]]; then
  log "✅ Restic restore completed successfully"
  
  # Fix ownership
  ensure_ownership "$RESTORE_TARGET"
  
  echo ""
  echo "✅ Restore completed successfully!"
  echo "📁 Data restored to: $RESTORE_TARGET"
  
  if [[ -n "$BACKUP_COPY" ]]; then
    echo "🧾 Original data backed up to: $BACKUP_COPY"
    echo "   Remove with: rm -rf \"$BACKUP_COPY\""
  fi
  
  echo ""
  echo "🔄 You may need to restart your Foundry container:"
  echo "   docker restart $FOUNDRY_CONTAINER_NAME"
  
else
  log "❌ Restic restore failed"
  exit 1
fi

log "============================================="