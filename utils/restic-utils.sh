#!/bin/bash
# === restic-utils.sh ===
# Shared helpers for all Restic operations

# Load unified configuration (this handles environment loading)
source "$(dirname "${BASH_SOURCE[0]}")/foundry-config.sh"

# Validate restic-specific environment variables
validate_restic_env() {
  local required_vars=(
    "RESTIC_REPO_DIR"
    "RESTIC_PASSWORD_FILE"
    "RESTIC_KEEP_DAILY"
    "RESTIC_KEEP_WEEKLY" 
    "RESTIC_KEEP_MONTHLY"
  )
  
  local missing_vars=()
  for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
      missing_vars+=("$var")
    fi
  done
  
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "❌ Missing required restic variables: ${missing_vars[*]}" >&2
    return 1
  fi
  
  return 0
}

# === Logging helper ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Check if the password file exists and is safe ===
check_restic_password_file() {
  if [[ ! -f "$RESTIC_PASSWORD_FILE" ]]; then
    echo "❌ Password file not found: $RESTIC_PASSWORD_FILE" >&2
    return 1
  fi

  local perms
  perms=$(stat -c "%a" "$RESTIC_PASSWORD_FILE")
  if [[ "$perms" != "600" ]]; then
    echo "⚠️ Password file permissions should be 600. Current: $perms" >&2
  fi

  return 0
}

# === Get the actual restic repository path ===
get_restic_repo_path() {
  # Use RESTIC_REPO_DIR from environment (set by foundry-config.sh)
  echo "$RESTIC_REPO_DIR"
}

# === Check if the repository is valid ===
restic_repo_check() {
  validate_restic_env || return 1
  check_restic_password_file || return 1
  
  local repo_path
  repo_path="$(get_restic_repo_path)"
  
  restic --repo "$repo_path" --password-file "$RESTIC_PASSWORD_FILE" snapshots &>/dev/null
  if [[ $? -ne 0 ]]; then
    echo "❌ Repository at $repo_path is not valid or not initialized." >&2
    return 1
  fi
  
  echo "✅ Restic repository is valid: $repo_path" >&2
  return 0
}

# === Initialize the repository if not already done ===
init_restic_repo() {
  validate_restic_env || return 1
  check_restic_password_file || return 1
  
  local repo_path
  repo_path="$(get_restic_repo_path)"
  
  if restic_repo_check; then
    echo "ℹ️ Repository already initialized." >&2
    return 0
  fi
  
  echo "📦 Initializing restic repo at: $repo_path" >&2
  restic init --repo "$repo_path" --password-file "$RESTIC_PASSWORD_FILE"
}

# === Log restic result ===
log_restic_result() {
  if [[ "$1" -eq 0 ]]; then
    log "✅ Restic command succeeded."
  else
    log "❌ Restic command failed with exit code: $1"
  fi
}

# === Run restic backup ===
run_restic_backup() {
  local source_path="$1"
  
  if [[ -z "$source_path" ]]; then
    echo "❌ No source path provided for backup" >&2
    return 1
  fi
  
  if [[ ! -d "$source_path" ]]; then
    echo "❌ Source path does not exist: $source_path" >&2
    return 1
  fi
  
  local repo_path
  repo_path="$(get_restic_repo_path)"
  
  restic --repo "$repo_path" --password-file "$RESTIC_PASSWORD_FILE" \
    backup "$source_path" --verbose
}

# === Run restic forget/prune ===
run_restic_prune() {
  local repo_path
  repo_path="$(get_restic_repo_path)"
  
  restic --repo "$repo_path" --password-file "$RESTIC_PASSWORD_FILE" \
    forget \
    --keep-daily "$RESTIC_KEEP_DAILY" \
    --keep-weekly "$RESTIC_KEEP_WEEKLY" \
    --keep-monthly "$RESTIC_KEEP_MONTHLY" \
    --prune
}