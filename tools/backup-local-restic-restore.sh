#!/bin/bash
# === backup-local-restic-restore.sh ===

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
LOG_FILE="$BACKUP_LOG_DIR/restic-restore-$(date +%F).log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

check_restic_password_file || exit 1
restic_repo_check || exit 1

SNAPSHOT_ID=""
for arg in "$@"; do
  case $arg in
    --id=*) SNAPSHOT_ID="${arg#*=}" ;;
    *) log "❌ Unknown argument: $arg"; exit 1 ;;
  esac
done

if [[ -z "$SNAPSHOT_ID" ]]; then
  log "❌ No snapshot ID provided. Use: --id=<snapshot>"
  exit 1
fi

RESTORE_TARGET="${FOUNDRY_DATA_DIR%/}/foundry-${FOUNDRY_TAG}/Data"

read -p "Back up current $RESTORE_TARGET before restoring? (y/n): " BACKUP_FIRST
if [[ "$BACKUP_FIRST" =~ ^[Yy]$ && -d "$RESTORE_TARGET" ]]; then
  BACKUP_COPY="$RESTORE_TARGET.before-restore-$(date +%Y%m%d%H%M)"
  cp -a "$RESTORE_TARGET" "$BACKUP_COPY"
  log "🗂️  Existing data backed up to: $BACKUP_COPY"
fi

log "♻️  Restoring snapshot $SNAPSHOT_ID..."
restic \
  --repo "$RESTIC_REPO" \
  --password-file "$RESTIC_PASSWORD_FILE" \
  restore "$SNAPSHOT_ID" \
  --target "$RESTORE_TARGET"

log_restic_result $?

if [[ -n "$BACKUP_COPY" ]]; then
  log "🧾 If satisfied, you can remove the backup: rm -rf \"$BACKUP_COPY\""
fi