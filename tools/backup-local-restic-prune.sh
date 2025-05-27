#!/bin/bash
# tools/backup-local-restic-prune.sh - Prune old restic snapshots

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
  "file-utils.sh" \
  "restic-utils.sh"

# === Setup logging ===
safe_mkdir "$FOUNDRY_BACKUP_LOG_DIR" || exit 1
LOG_FILE="$FOUNDRY_BACKUP_LOG_DIR/restic-prune-$(date +%F).log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

log "🧹 Starting Restic prune operation"
log "📂 Repository: $RESTIC_REPO"
log "📝 Log: $LOG_FILE"
log "🔄 Retention: ${RESTIC_KEEP_DAILY}d/${RESTIC_KEEP_WEEKLY}w/${RESTIC_KEEP_MONTHLY}m"
log "---------------------------------------------"

# === Pre-flight checks ===
validate_restic_env || exit 1
restic_repo_check || exit 1

# === Run the prune ===
log "🔄 Running restic forget & prune..."
if run_restic_prune; then
  log "✅ Restic prune completed successfully"
else
  log "❌ Restic prune failed"
  exit 1
fi

log "📊 Repository statistics after prune:"
restic --repo "$RESTIC_REPO" --password-file "$RESTIC_PASSWORD_FILE" stats 2>/dev/null | while read -r line; do
  log "   $line"
done

log "============================================="