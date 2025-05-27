#!/bin/bash
# tools/validate-config.sh - Validate Foundry VTT configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"

# Load unified configuration helper
source "$UTILS_DIR/foundry-config.sh"

echo "🔍 Validating Foundry VTT Configuration"
echo "========================================"

# The foundry-config.sh helper already validated env vars and computed paths
# If we got here without errors, basic validation passed

echo ""
echo "📋 Current Configuration:"
show_foundry_config

# Check if paths exist
echo ""
echo "📁 Checking computed paths..."
if [[ -d "$FOUNDRY_INSTALL_PATH" ]]; then
  echo "✅ Install directory exists"
else
  echo "⚠️  Install directory not found (normal if not yet installed)"
fi

if [[ -d "$FOUNDRY_DATA_PATH" ]]; then
  echo "✅ Data directory exists"
else
  echo "⚠️  Data directory not found (normal if not yet installed)"
fi

# Check Docker
echo ""
echo "🐳 Checking Docker..."
if command -v docker >/dev/null 2>&1; then
  echo "✅ Docker is installed"
  
  if docker ps >/dev/null 2>&1; then
    echo "✅ Docker is running"
    
    if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
      status=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
      echo "✅ Container '$CONTAINER_NAME' exists (status: $status)"
    else
      echo "⚠️  Container '$CONTAINER_NAME' not found (normal if not yet created)"
    fi
  else
    echo "❌ Docker is not running or permission denied"
  fi
else
  echo "❌ Docker is not installed"
fi

# Check backup tools
echo ""
echo "🛠️ Checking backup tools..."
for tool in rsync restic rclone; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "✅ $tool is installed"
  else
    echo "⚠️  $tool is not installed"
  fi
done

# Check disk space
echo ""
echo "💾 Checking disk space..."
for path in "$FOUNDRY_DATA_PATH" "$FOUNDRY_BACKUP_LOG_DIR"; do
  if [[ -d "$(dirname "$path")" ]]; then
    available=$(df -BM "$(dirname "$path")" | awk 'NR==2 {print $4}' | sed 's/M//')
    if [[ $available -gt 1000 ]]; then
      echo "✅ $(dirname "$path"): ${available}MB available"
    else
      echo "⚠️  $(dirname "$path"): Only ${available}MB available"
    fi
  fi
done

echo ""
echo "🎉 Configuration validation complete!"