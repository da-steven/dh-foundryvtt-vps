#!/bin/bash
# === backup-local-restic.sh ===

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

safe_mkdir "$BACKUP_LOG_DIR" || exit 1
LOG_FILE="$BACKUP_LOG_DIR/restic-backup-$(date +%F).log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

BACKUP_SOURCE="${FOUNDRY_DATA_DIR%/}/foundry-${FOUNDRY_TAG}/Data"
check_disk_space "$BACKUP_SOURCE" 500 || {
  log "❌ Not enough disk space. Aborting."
  exit 1
}

check_restic_password_file || exit 1
restic_repo_check || exit 1

log "📦 Starting Restic backup for $BACKUP_SOURCE"
restic \
  --repo "$RESTIC_REPO" \
  --password-file "$RESTIC_PASSWORD_FILE" \
  backup "$BACKUP_SOURCE" --verbose

log_restic_result $?