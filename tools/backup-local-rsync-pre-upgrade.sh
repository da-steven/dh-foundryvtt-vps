#!/bin/bash
# tools/backup-pre-upgrade.sh - Quick backup before Foundry upgrades
# ‼️WARNING: This script is work-in-progress placeholder. 
# TODO: This is a WIP script that I will integrate into our eventual Foundry updgrate workdlow.

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
  "file-utils.sh" 

echo "🔄 Pre-Upgrade Backup"
echo "===================="
echo ""
echo "📦 Creating quick rsync snapshot before upgrade..."
echo "📁 Source: $FOUNDRY_BACKUP_SOURCE"
echo ""

# Stop Foundry container to ensure consistent backup
if docker ps --format '{{.Names}}' | grep -qx "$FOUNDRY_CONTAINER_NAME"; then
  echo "🛑 Stopping Foundry container for consistent backup..."
  docker stop "$FOUNDRY_CONTAINER_NAME"
  NEED_RESTART=true
else
  NEED_RESTART=false
fi

# Run rsync backup with special naming
BACKUP_NAME="pre-upgrade-$(date +%Y-%m-%d-%H%M%S)"
UPGRADE_BACKUP_DIR="$FOUNDRY_RSYNC_BACKUP_PATH/$BACKUP_NAME"

# Ensure backup directory exists
safe_mkdir "$FOUNDRY_RSYNC_BACKUP_PATH" || exit 1

# Create the backup
echo "📦 Creating backup: $BACKUP_NAME"
rsync -a "$FOUNDRY_BACKUP_SOURCE/" "$UPGRADE_BACKUP_DIR/"

if [[ $? -eq 0 ]]; then
  echo "✅ Pre-upgrade backup completed successfully!"
  echo "📁 Backup location: $UPGRADE_BACKUP_DIR"
  echo "📊 Backup size: $(du -sh "$UPGRADE_BACKUP_DIR" | cut -f1)"
  
  # Create a restoration script
  cat > "$UPGRADE_BACKUP_DIR/RESTORE.sh" << EOF
#!/bin/bash
# Quick restore script for this backup
echo "🔄 Restoring from pre-upgrade backup..."
echo "📁 Target: $FOUNDRY_BACKUP_SOURCE"
read -p "Continue? This will overwrite current data! (y/n): " confirm
if [[ \$confirm =~ ^[Yy]$ ]]; then
  rsync -a --delete "$UPGRADE_BACKUP_DIR/" "$FOUNDRY_BACKUP_SOURCE/"
  echo "✅ Restore complete!"
  echo "🔄 Restart Foundry: docker restart $FOUNDRY_CONTAINER_NAME"
else
  echo "❌ Restore cancelled"
fi
EOF
  chmod +x "$UPGRADE_BACKUP_DIR/RESTORE.sh"
  echo "📝 Quick restore script created: $UPGRADE_BACKUP_DIR/RESTORE.sh"
  
else
  echo "❌ Backup failed!"
  exit 1
fi

# Restart container if we stopped it
if [[ "$NEED_RESTART" == "true" ]]; then
  echo "🔄 Restarting Foundry container..."
  docker start "$FOUNDRY_CONTAINER_NAME"
fi

echo ""
echo "🎯 Next steps:"
echo "   1. Proceed with your Foundry upgrade"
echo "   2. Test thoroughly"
echo "   3. If issues occur, run: bash $UPGRADE_BACKUP_DIR/RESTORE.sh"
echo ""
echo "💡 This backup will be kept separate from regular rsync rotations."