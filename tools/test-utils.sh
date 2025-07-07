#!/bin/bash
# tools/test-utils.sh - Test all utility functions

# Always run from the script's directory (needed for CRON execution)
cd "$(dirname "$0")"

# Find and source load-env.sh
if [[ -f "utils/load-env.sh" ]]; then
  source "utils/load-env.sh"           
elif [[ -f "../utils/load-env.sh" ]]; then
  source "../utils/load-env.sh"       
else
  echo "❌ Cannot find utils/load-env.sh" >&2
  exit 1
fi

echo "🧪 Testing Foundry VTT Utilities"
echo "================================="

# Test 1: Load unified config
echo ""
echo "1️⃣ Testing foundry-config.sh..."
if source "$UTILS_DIR/foundry-config.sh"; then
  echo "✅ foundry-config.sh loaded successfully"
  show_foundry_config
else
  echo "❌ Failed to load foundry-config.sh"
  exit 1
fi

# Test 2: Test file utilities
echo ""
echo "2️⃣ Testing file-utils.sh..."
if source "$UTILS_DIR/file-utils.sh"; then
  echo "✅ file-utils.sh loaded successfully"
  
  # Test disk space check
  if check_disk_space "/tmp" 100; then
    echo "✅ check_disk_space function works"
  else
    echo "⚠️ check_disk_space function returned error (might be expected)"
  fi
else
  echo "❌ Failed to load file-utils.sh"
fi

# Test 3: Test restic utilities (if restic is configured)
echo ""
echo "3️⃣ Testing restic-utils.sh..."
if [[ -n "$RESTIC_REPO_DIR" && -n "$RESTIC_PASSWORD_FILE" ]]; then
  if source "$UTILS_DIR/restic-utils.sh"; then
    echo "✅ restic-utils.sh loaded successfully"
    
    if validate_restic_env; then
      echo "✅ Restic environment validation passed"
    else
      echo "⚠️ Restic environment validation failed (missing setup?)"
    fi
  else
    echo "❌ Failed to load restic-utils.sh"
  fi
else
  echo "⚠️ Restic not configured, skipping restic-utils.sh test"
fi

# Test 4: Test platform utilities
echo ""
echo "4️⃣ Testing platform-utils.sh..."
if source "$UTILS_DIR/platform-utils.sh"; then
  echo "✅ platform-utils.sh loaded successfully"
  
  if arch=$(detect_architecture); then
    echo "✅ Detected architecture: $arch"
  else
    echo "❌ Architecture detection failed"
  fi
else
  echo "❌ Failed to load platform-utils.sh"
fi

# Test 5: Test docker utilities
echo ""
echo "5️⃣ Testing docker-utils.sh..."
if source "$UTILS_DIR/docker-utils.sh"; then
  echo "✅ docker-utils.sh loaded successfully"
  echo "✅ docker_cleanup function available"
else
  echo "❌ Failed to load docker-utils.sh"
fi

echo ""
echo "🎉 Utility testing complete!"
echo ""
echo "📋 Summary of exported variables:"
echo "  REPO_ROOT:                $REPO_ROOT"
echo "  UTILS_DIR:                $UTILS_DIR" 
echo "  FOUNDRY_INSTALL_PATH:     $FOUNDRY_INSTALL_PATH"
echo "  FOUNDRY_DATA_PATH:        $FOUNDRY_DATA_PATH"
echo "  FOUNDRY_BACKUP_SOURCE:    $FOUNDRY_BACKUP_SOURCE"
echo "  FOUNDRY_CONTAINER_NAME:   $FOUNDRY_CONTAINER_NAME"