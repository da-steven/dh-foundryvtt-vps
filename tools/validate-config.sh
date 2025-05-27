#!/bin/bash
# tools/validate-config.sh - Validate Foundry VTT configuration

# Find and source load-env.sh
if [[ -f "utils/load-env.sh" ]]; then
  source "utils/load-env.sh"           
elif [[ -f "../utils/load-env.sh" ]]; then
  source "../utils/load-env.sh"       
else
  echo "❌ Cannot find utils/load-env.sh" >&2
  exit 1
fi

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
    
    # Debug: Show what we're looking for
    # echo "🔍 Looking for container: '$FOUNDRY_CONTAINER_NAME'"
    
    if [[ -n "$FOUNDRY_CONTAINER_NAME" ]] && docker ps -a --format '{{.Names}}' | grep -qx "$FOUNDRY_CONTAINER_NAME"; then
      status=$(docker inspect -f '{{.State.Status}}' "$FOUNDRY_CONTAINER_NAME" 2>/dev/null)
      echo "✅ Container '$FOUNDRY_CONTAINER_NAME' exists (status: $status)"
    else
      if [[ -z "$FOUNDRY_CONTAINER_NAME" ]]; then
        echo "❌ FOUNDRY_CONTAINER_NAME is empty - configuration error"
        echo "   Expected format: foundryvtt-v12"
        echo "   Debug info: FOUNDRY_TAG='$FOUNDRY_TAG'"
      else
        echo "⚠️  Container '$FOUNDRY_CONTAINER_NAME' not found"
        echo "   Available containers:"
        docker ps -a --format "   {{.Names}} ({{.Status}})" | head -5
      fi
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
  parent_dir="$(dirname "$path")"
  if [[ -d "$parent_dir" ]]; then
    available=$(df -BM "$parent_dir" | awk 'NR==2 {print $4}' | sed 's/M//')
    if [[ $available -gt 1000 ]]; then
      echo "✅ $parent_dir: ${available}MB available"
    else
      echo "⚠️  $parent_dir: Only ${available}MB available"
    fi
  else
    echo "⚠️  $parent_dir: Directory does not exist"
  fi
done

echo ""
echo "🎉 Configuration validation complete!"