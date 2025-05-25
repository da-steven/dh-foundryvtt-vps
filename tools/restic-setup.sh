#!/bin/bash
# === restic-setup.sh ===
# Installs Restic and configures a local encrypted repository

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

# === Ensure log directory and file ===
safe_mkdir "$BACKUP_LOG_DIR" || exit 1
LOG_FILE="$BACKUP_LOG_DIR/restic-setup-$(date +%F).log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Check for restic ===
if ! command -v restic &>/dev/null; then
  log "📦 Installing Restic..."
  sudo apt update && sudo apt install -y restic || {
    log "❌ Failed to install restic. Aborting."
    exit 1
  }
else
  log "✅ Restic is already installed."
fi

# === Handle password file ===
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

# === Prepare repo directory ===
safe_mkdir "$RESTIC_REPO" || exit 1

# === Optional: Check for disk space ===
check_disk_space "$RESTIC_REPO" 500 || {
  log "❌ Not enough free space in $RESTIC_REPO. Aborting."
  exit 1
}

# === Initialize restic repo ===
init_restic_repo

# === Setup retention policy ===
DAILY="${RESTIC_KEEP_DAILY:-7}"
WEEKLY="${RESTIC_KEEP_WEEKLY:-4}"
MONTHLY="${RESTIC_KEEP_MONTHLY:-6}"

log "🧹 Applying retention policy: daily=$DAILY, weekly=$WEEKLY, monthly=$MONTHLY"
restic \
  --repo "$RESTIC_REPO" \
  --password-file "$RESTIC_PASSWORD_FILE" \
  forget \
  --keep-daily "$DAILY" \
  --keep-weekly "$WEEKLY" \
  --keep-monthly "$MONTHLY" \
  --prune >> "$LOG_FILE" 2>&1

log ""
log "🎉 Restic setup complete."
log "🗂️  Repo: $RESTIC_REPO"
log "🗓️ Retention policy:"
log "  - Daily:     $DAILY"
log "  - Weekly:    $WEEKLY"
log "  - Monthly:   $MONTHLY"
log "🔐 Password File: $RESTIC_PASSWORD_FILE"
log ""