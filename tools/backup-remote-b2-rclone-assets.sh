#!/bin/bash
# tools/backup-remote-b2-assets.sh - Remote backup of shared assets folder to Backblaze B2

# Always run from the script's directory (needed for CRON execution)
cd "$(dirname "$0")"

# === Bootstrap Environment ===
if [[ -f "utils/load-env.sh" ]]; then
  source "utils/load-env.sh"
elif [[ -f "../utils/load-env.sh" ]]; then
  source "../utils/load-env.sh"
else
  echo "❌ Cannot find utils/load-env.sh" >&2
  exit 1
fi

# Load helpers
load_helpers "file-utils.sh" "tool-utils.sh" "send-email-mailjet.sh"

# === Sanity Checks ===
: "${FOUNDRY_SHARED_ASSETS:?FOUNDRY_SHARED_ASSETS not set in .env}"
: "${B2_BUCKET_NAME_ASSETS:?B2_BUCKET_NAME_ASSETS not set in .env}"
: "${FOUNDRY_BACKUP_LOG_DIR:?FOUNDRY_BACKUP_LOG_DIR not set in .env}"

# === Setup ===
# Configuration for shared assets backup
B2_ASSETS_REMOTE="b2-assets"
B2_ASSETS_BUCKET="$B2_BUCKET_NAME_ASSETS"
DEST_REMOTE="$B2_ASSETS_REMOTE:$B2_ASSETS_BUCKET"
LOG_FILE="$FOUNDRY_BACKUP_LOG_DIR/b2-assets-backup-log-$(date +%F).txt"

safe_mkdir "$FOUNDRY_BACKUP_LOG_DIR"

log() {
  echo "$(date '+%F %T') | $*" | tee -a "$LOG_FILE"
}

log "🎨 Starting B2 shared assets backup"
log "📂 Source: $FOUNDRY_SHARED_ASSETS"
log "📁 Destination: $DEST_REMOTE"
log "📝 Log file: $LOG_FILE"
log "---------------------------------------------"

# === Tool Check ===
check_tool rclone || exit 1

# === Exclude File ===
EXCLUDE_FILE=$(get_backup_excludes "b2")
if [[ -z "$EXCLUDE_FILE" || ! -s "$EXCLUDE_FILE" ]]; then
  log "❌ Failed to generate filtered exclude file for B2"
  send_email "B2 Assets Backup Failed" \
    "B2 shared assets backup aborted: no valid exclude file generated at $(date).\nCheck your .backup-exclude.txt for formatting or path issues."
  exit 1
fi

# === Source Check ===
if [[ ! -d "$FOUNDRY_SHARED_ASSETS" ]]; then
  log "❌ Shared assets directory not found: $FOUNDRY_SHARED_ASSETS"
  send_email "B2 Assets Backup Failed" \
    "B2 shared assets backup aborted: Directory not found: $FOUNDRY_SHARED_ASSETS"
  exit 1
fi

log "🚀 Running B2 shared assets backup job..."

# Detect if running interactively (terminal) or via cron (no terminal)
if [[ -t 1 ]]; then
  # Interactive mode - show progress and log
  log "ℹ️ Interactive mode detected - showing progress"
  rclone copy "$FOUNDRY_SHARED_ASSETS" "$DEST_REMOTE" \
    --exclude-from="$EXCLUDE_FILE" \
    --transfers=8 \
    --checkers=4 \
    --fast-list \
    --log-level INFO \
    --log-file="$LOG_FILE" \
    --progress
else
  # Cron/non-interactive mode - log only, no console output
  log "ℹ️ Non-interactive mode detected - logging only"
  rclone copy "$FOUNDRY_SHARED_ASSETS" "$DEST_REMOTE" \
    --exclude-from="$EXCLUDE_FILE" \
    --transfers=8 \
    --checkers=4 \
    --fast-list \
    --log-level INFO \
    --log-file="$LOG_FILE" \
    --quiet
fi

STATUS=$?

if [[ $STATUS -eq 0 ]]; then
  log "✅ B2 shared assets backup completed successfully."
  send_email "B2 Assets Backup Successful" "B2 shared assets backup completed successfully on $(date)."
else
  log "❌ B2 shared assets backup failed with exit code: $STATUS"
  send_email "B2 Assets Backup Failed" \
    "B2 shared assets backup failed with exit code $STATUS at $(date).\nLog: $LOG_FILE"
  exit $STATUS
fi

log "============================================="