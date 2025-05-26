#!/bin/bash
# === restic-setup.sh ===
# Installs Restic and configures a local encrypted repository

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

# === Verify required ENV values ===
if [[ -z "$RESTIC_REPO" ]]; then
  echo "❌ RESTIC_REPO is not set. Check your .env.local or .env.defaults."
  exit 1
fi

if [[ -z "$RESTIC_PASSWORD_FILE" ]]; then
  echo "❌ RESTIC_PASSWORD_FILE is not set. Check your .env.local or .env.defaults."
  exit 1
fi

if [[ -z "$BACKUP_LOG_DIR" ]]; then
  echo "❌ BACKUP_LOG_DIR is not set. Check your .env.local or .env.defaults."
  exit 1
fi

# === Prepare log ===
safe_mkdir "$BACKUP_LOG_DIR" || exit 1
LOG_FILE="$BACKUP_LOG_DIR/restic-setup-$(date +%F).log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Ensure restic is installed ===
if ! command -v restic &>/dev/null; then
  log "📦 Installing Restic..."
  sudo apt update && sudo apt install -y restic || {
    log "❌ Failed to install restic. Aborting."
    exit 1
  }
else
  log "✅ Restic is already installed."
fi

# === Check if password file already exists ===
if [[ -s "$RESTIC_PASSWORD_FILE" ]]; then
  log "⚠️ Password file already exists: $RESTIC_PASSWORD_FILE"
  read -p "Do you want to overwrite it? (y/n): " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    log "❌ Aborting to avoid overwriting existing password."
    exit 1
  fi
  TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
  BACKUP="$RESTIC_PASSWORD_FILE.bak.$TIMESTAMP"
  cp "$RESTIC_PASSWORD_FILE" "$BACKUP"
  log "🧾 Original password file backed up as: $BACKUP"
fi

# === Prompt for new password ===
echo "🔐 Set a password for the Restic repository."
read -s -p "Enter password: " PW1; echo
read -s -p "Confirm password: " PW2; echo

if [[ "$PW1" != "$PW2" ]]; then
  log "❌ Passwords do not match. Aborting."
  exit 1
fi

echo "$PW1" > "$RESTIC_PASSWORD_FILE"
chmod 600 "$RESTIC_PASSWORD_FILE"
log "✅ Password saved to: $RESTIC_PASSWORD_FILE"

# === Ensure repo dir exists ===
safe_mkdir "$RESTIC_REPO" || exit 1

# === Check disk space ===
check_disk_space "$RESTIC_REPO" 500 || {
  log "❌ Not enough free space in $RESTIC_REPO. Aborting."
  exit 1
}

# === Initialize repo if needed ===
init_restic_repo

# === Setup retention policy ===
KEEP_DAILY="${RESTIC_KEEP_DAILY:-7}"
KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${RESTIC_KEEP_MONTHLY:-6}"

log "🛠️ Applying retention policy..."
restic \
  --repo "$RESTIC_REPO" \
  --password-file "$RESTIC_PASSWORD_FILE" \
  forget \
  --keep-daily "$KEEP_DAILY" \
  --keep-weekly "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY" \
  --prune

log ""
log "🎉 Restic setup complete."
log "🗂️  Repo: $RESTIC_REPO"
log "🔐 Password File: $RESTIC_PASSWORD_FILE"