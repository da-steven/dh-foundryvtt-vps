#!/bin/bash
# tools/backup-local-restic.sh - Local encrypted backups using restic

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
LOG_FILE="$FOUNDRY_BACKUP_LOG_DIR/restic-backup-$(date +%F).log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

log "📦 Starting Restic backup for: $FOUNDRY_BACKUP_SOURCE"
log "📂 Repository: $RESTIC_REPO"
log "📝 Log: $LOG_FILE"
log "---------------------------------------------"

# === Pre-flight checks ===
check_disk_space "$FOUNDRY_BACKUP_SOURCE" 500 || {
  log "❌ Not enough disk space. Aborting."
  exit 1
}

# Validate restic environment and repository
validate_restic_env || exit 1
restic_repo_check || exit 1

# === Run the backup ===
log "🔄 Running restic backup..."
if run_restic_backup "$FOUNDRY_BACKUP_SOURCE"; then
  log "✅ Restic backup completed successfully"
else
  log "❌ Restic backup failed"
  exit 1
fi

log "📊 Repository statistics:"
restic --repo "$RESTIC_REPO" --password-file "$RESTIC_PASSWORD_FILE" stats latest 2>/dev/null | while read -r line; do
  log "   $line"
done

log "============================================="