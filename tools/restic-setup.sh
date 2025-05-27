#!/bin/bash
# tools/restic-setup.sh - Install and configure restic for encrypted backups

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
LOG_FILE="$FOUNDRY_BACKUP_LOG_DIR/restic-setup-$(date +%F).log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

echo "🔐 Restic Setup - Encrypted Backup Configuration"
echo "================================================"
echo ""

log "🚀 Starting restic setup process"
log "📂 Repository will be: $RESTIC_REPO"
log "🔐 Password file will be: $RESTIC_PASSWORD_FILE"
log "📝 Setup log: $LOG_FILE"

# === Check if already configured ===
if [[ -f "$RESTIC_PASSWORD_FILE" && -d "$RESTIC_REPO" ]]; then
  echo "⚠️  Restic appears to already be configured:"
  echo "   Password file: $RESTIC_PASSWORD_FILE"
  echo "   Repository:    $RESTIC_REPO"
  echo ""
  read -p "   Continue anyway? This will overwrite existing setup. (y/n): " CONTINUE
  if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    echo "⛔ Setup cancelled."
    exit 0
  fi
fi

# === Install restic if needed ===
if ! command -v restic &>/dev/null; then
  log "📦 Installing restic..."
  echo "📦 Installing restic..."
  sudo apt update && sudo apt install -y restic || {
    log "❌ Failed to install restic"
    echo "❌ Failed to install restic. Aborting."
    exit 1
  }
  log "✅ Restic installed successfully"
  echo "✅ Restic installed successfully"
else
  log "✅ Restic is already installed: $(restic version)"
  echo "✅ Restic is already installed: $(restic version)"
fi

# === Backup existing password file if it exists ===
if [[ -s "$RESTIC_PASSWORD_FILE" ]]; then
  TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
  BACKUP_FILE="$RESTIC_PASSWORD_FILE.backup.$TIMESTAMP"
  cp "$RESTIC_PASSWORD_FILE" "$BACKUP_FILE"
  log "🧾 Existing password file backed up to: $BACKUP_FILE"
  echo "🧾 Existing password file backed up to: $BACKUP_FILE"
fi

# === Set password ===
echo ""
echo "🔐 Setting up repository password..."
echo "   This password encrypts your backups. Keep it safe!"
echo "   If you lose it, you cannot recover your backups."
echo ""

while true; do
  read -s -p "Enter password for restic repository: " PASSWORD1
  echo ""
  read -s -p "Confirm password: " PASSWORD2
  echo ""
  
  if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
    if [[ ${#PASSWORD1} -lt 8 ]]; then
      echo "❌ Password too short. Please use at least 8 characters."
      continue
    fi
    break
  else
    echo "❌ Passwords do not match. Please try again."
  fi
done

# === Save password file ===
echo "$PASSWORD1" > "$RESTIC_PASSWORD_FILE"
chmod 600 "$RESTIC_PASSWORD_FILE"
log "✅ Password saved to: $RESTIC_PASSWORD_FILE"
echo "✅ Password saved securely"

# === Create and check repository directory ===
safe_mkdir "$RESTIC_REPO" || {
  log "❌ Failed to create repository directory: $RESTIC_REPO"
  echo "❌ Failed to create repository directory"
  exit 1
}

# === Check disk space ===
echo ""
echo "💾 Checking disk space..."
check_disk_space "$RESTIC_REPO" 500 || {
  log "❌ Insufficient disk space for repository"
  echo "❌ Not enough free space for repository"
  echo "   Need at least 500MB, preferably several GB for backups"
  exit 1
}

# === Initialize repository ===
echo ""
echo "📦 Initializing restic repository..."
log "📦 Initializing repository at: $RESTIC_REPO"

if init_restic_repo; then
  log "✅ Repository initialized successfully"
  echo "✅ Repository initialized successfully"
else
  log "❌ Failed to initialize repository"
  echo "❌ Failed to initialize repository"
  exit 1
fi

# === Test repository ===
echo ""
echo "🧪 Testing repository access..."
if restic_repo_check; then
  echo "✅ Repository test passed"
else
  echo "❌ Repository test failed"
  exit 1
fi

# === Show configuration ===
echo ""
echo "📋 Restic Configuration Summary:"
echo "   Repository:     $RESTIC_REPO"
echo "   Password File:  $RESTIC_PASSWORD_FILE"
echo "   Retention:"
echo "     Daily:        ${RESTIC_KEEP_DAILY} backups"
echo "     Weekly:       ${RESTIC_KEEP_WEEKLY} backups" 
echo "     Monthly:      ${RESTIC_KEEP_MONTHLY} backups"
echo ""

# === Test backup (optional) ===
read -p "🧪 Run a test backup now? (y/n): " TEST_BACKUP
if [[ "$TEST_BACKUP" =~ ^[Yy]$ ]]; then
  echo ""
  echo "🔄 Running test backup..."
  
  # Create a small test file
  TEST_DIR="/tmp/restic-test-$$"
  mkdir -p "$TEST_DIR"
  echo "Test backup file created $(date)" > "$TEST_DIR/test.txt"
  
  if run_restic_backup "$TEST_DIR"; then
    echo "✅ Test backup completed successfully"
    log "✅ Test backup completed successfully"
    
    # Clean up test file
    rm -rf "$TEST_DIR"
    
    # Show snapshots
    echo ""
    echo "📋 Repository snapshots:"
    restic --repo "$RESTIC_REPO" --password-file "$RESTIC_PASSWORD_FILE" snapshots
  else
    echo "❌ Test backup failed"
    log "❌ Test backup failed"
    rm -rf "$TEST_DIR"
  fi
fi

# === Setup complete ===
echo ""
echo "🎉 Restic setup completed successfully!"
echo ""
echo "📝 Next steps:"
echo "   1. Test backup: bash tools/backup-local-restic.sh"
echo "   2. Set up cron job for automated backups"
echo "   3. Test restore: bash tools/backup-local-restic-restore.sh --list"
echo ""
echo "⚠️  IMPORTANT: Keep your password file safe!"
echo "   Location: $RESTIC_PASSWORD_FILE"
echo "   Without it, you cannot access your backups!"

log "🎉 Restic setup completed successfully"
log "============================================="