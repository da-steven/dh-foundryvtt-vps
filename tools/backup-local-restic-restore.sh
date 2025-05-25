#!/bin/bash

# === backup-restore-restic.sh ===
# Restore from a restic snapshot, defaulting to the latest.

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

# === Config ===
safe_mkdir "$BACKUP_LOG_DIR" || exit 1
LOG_FILE="$BACKUP_LOG_DIR/restic-restore-$(date +%F).log"

RESTORE_TARGET="${FOUNDRY_DATA_DIR%/}/$FOUNDRY_TAG/Data"
TIMESTAMP=$(date +%Y-%m-%d-%H%M)
BACKUP_COPY="$RESTORE_TARGET.before-restore-$TIMESTAMP"

# === Logging ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Parse Flags ===
SNAPSHOT_ID=""
for arg in "$@"; do
  case $arg in
    --id=*)
      SNAPSHOT_ID="${arg#*=}"
      ;;
    *)
      log "❌ Unknown argument: $arg"
      exit 1
      ;;
  esac
done

# === Checks ===
if ! command -v restic &>/dev/null; then
  log "❌ Restic not installed. Aborting."
  exit 1
fi

if [[ ! -f "$RESTIC_PASSWORD_FILE" || ! -s "$RESTIC_PASSWORD_FILE" ]]; then
  log "❌ Password file missing or empty: $RESTIC_PASSWORD_FILE"
  exit 1
fi

restic_repo_check || exit 1

# === Select Snapshot ===
if [[ -n "$SNAPSHOT_ID" ]]; then
  log "📦 Using snapshot ID: $SNAPSHOT_ID"
else
  log "📦 Fetching latest snapshot..."
  SNAPSHOT_ID=$(restic snapshots --latest 1 --json \
    --repo "$RESTIC_REPO" \
    --password-file "$RESTIC_PASSWORD_FILE" | jq -r '.[0].short_id')
  
  if [[ -z "$SNAPSHOT_ID" ]]; then
    log "❌ Failed to find a valid snapshot."
    exit 1
  fi

  log "📦 Latest snapshot ID: $SNAPSHOT_ID"
fi

log "📂 Restore target: $RESTORE_TARGET"
log "📝 Log: $LOG_FILE"
log "-----------------------------------------"

# === Confirm Restore ===
read -p "Are you sure you want to restore to $RESTORE_TARGET? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && {
  log "❌ Restore aborted by user."
  exit 1
}

# === Offer Pre-Restore Backup ===
if [[ -d "$RESTORE_TARGET" && "$(ls -A "$RESTORE_TARGET")" ]]; then
  read -p "Backup existing data to $BACKUP_COPY before restore? (y/n): " BACKUP_CONFIRM
  if [[ "$BACKUP_CONFIRM" =~ ^[Yy]$ ]]; then
    log "📁 Backing up existing data to: $BACKUP_COPY"
    cp -a "$RESTORE_TARGET" "$BACKUP_COPY"
  fi
fi

# === Run Restore ===
log "♻️ Restoring snapshot..."
restic restore "$SNAPSHOT_ID" \
  --repo "$RESTIC_REPO" \
  --target "$RESTORE_TARGET" \
  --password-file "$RESTIC_PASSWORD_FILE" >> "$LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
  log "✅ Restore completed successfully."
  [[ -d "$BACKUP_COPY" ]] && log "🧾 To remove the backup: rm -rf \"$BACKUP_COPY\""
else
  log "❌ Restore failed. Check log: $LOG_FILE"
  exit 1
fi

log "========================================="