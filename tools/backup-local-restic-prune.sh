#!/bin/bash
# === backup-local-restic-prune.sh ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
source "$UTILS_DIR/load-env.sh"
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
LOG_FILE="$BACKUP_LOG_DIR/restic-prune-$(date +%F).log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

check_restic_password_file || exit 1
restic_repo_check || exit 1

KEEP_DAILY="${RESTIC_KEEP_DAILY:-7}"
KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${RESTIC_KEEP_MONTHLY:-6}"

log "🧹 Running Restic prune: keep $KEEP_DAILY daily, $KEEP_WEEKLY weekly, $KEEP_MONTHLY monthly"

restic \
  --repo "$RESTIC_REPO" \
  --password-file "$RESTIC_PASSWORD_FILE" \
  forget \
  --keep-daily "$KEEP_DAILY" \
  --keep-weekly "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY" \
  --prune

log_restic_result $?