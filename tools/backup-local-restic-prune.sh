#!/bin/bash

# === backup-prune-restic.sh ===
# Applies the Restic retention policy using `forget --prune`

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/../utils"
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"
RESTIC_UTILS="$UTILS_DIR/restic-utils.sh"

for helper in "$ENV_LOADER" "$FILE_UTILS" "$RESTIC_UTILS"; do
  [[ -f "$helper" ]] && source "$helper" || {
    echo "❌ Missing helper: $helper"
    exit 1
  }
done

# === Config & Logging ===
safe_mkdir "$BACKUP_LOG_DIR" || exit 1
LOG_FILE="$BACKUP_LOG_DIR/restic-prune-$(date +%F).log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Safety Checks ===
if ! command -v restic &>/dev/null; then
  log "❌ Restic is not installed. Aborting."
  exit 1
fi

if [[ ! -f "$RESTIC_PASSWORD_FILE" ]]; then
  log "❌ Password file missing: $RESTIC_PASSWORD_FILE"
  exit 1
fi

if [[ ! -s "$RESTIC_PASSWORD_FILE" ]]; then
  log "❌ Password file is empty: $RESTIC_PASSWORD_FILE"
  exit 1
fi

restic_repo_check || exit 1

# === Retention Values (with fallback) ===
KEEP_DAILY="${RESTIC_KEEP_DAILY:-7}"
KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${RESTIC_KEEP_MONTHLY:-6}"

log "🗂️  Applying retention policy to: $RESTIC_REPO"
log "🧹 Keep: $KEEP_DAILY daily, $KEEP_WEEKLY weekly, $KEEP_MONTHLY monthly"
log "📝 Log file: $LOG_FILE"
log "---------------------------------------------"

restic forget \
  --repo "$RESTIC_REPO" \
  --password-file "$RESTIC_PASSWORD_FILE" \
  --keep-daily "$KEEP_DAILY" \
  --keep-weekly "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY" \
  --prune \
  --verbose >> "$LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
  log "✅ Prune completed successfully."
else
  log "❌ Prune failed. See log for details."
  exit 1
fi

log "============================================="
