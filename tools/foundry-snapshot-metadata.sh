#!/bin/bash
# tools/foundry-snapshot-metadata.sh
# Captures Foundry module/system metadata (CSV + JSON) with timestamp

set -euo pipefail

# Find and source load-env.sh
if [[ -f "utils/load-env.sh" ]]; then
  source "utils/load-env.sh"           
elif [[ -f "../utils/load-env.sh" ]]; then
  source "../utils/load-env.sh"       
else
  echo "❌ Cannot find utils/load-env.sh" >&2
  exit 1
fi
load_helpers "file-utils.sh" "tool-utils.sh"

# === Directories ===
DATESTAMP=$(date +%F)
SNAPSHOT_DIR="${FOUNDRY_DATA_DIR}/Backups/snapshots"
MODULES_DIR="${FOUNDRY_DATA_DIR}/Data/modules"
SYSTEMS_DIR="${FOUNDRY_DATA_DIR}/Data/systems"

safe_mkdir "$SNAPSHOT_DIR"

# === CSV Headers ===
MODULES_CSV="$SNAPSHOT_DIR/modules-$DATESTAMP.csv"
SYSTEMS_CSV="$SNAPSHOT_DIR/systems-$DATESTAMP.csv"
MODULES_JSON="$SNAPSHOT_DIR/modules-$DATESTAMP.json"
SYSTEMS_JSON="$SNAPSHOT_DIR/systems-$DATESTAMP.json"

echo "name,title,version,manifest,download" > "$MODULES_CSV"
echo "name,title,version,manifest,download" > "$SYSTEMS_CSV"

# === Collect module metadata ===
for file in "$MODULES_DIR"/*/module.json; do
  [[ -f "$file" ]] || continue
  jq -r '[.name, .title, .version, .manifest, .download] | @csv' "$file" >> "$MODULES_CSV"
done

# === Collect system metadata ===
for file in "$SYSTEMS_DIR"/*/system.json; do
  [[ -f "$file" ]] || continue
  jq -r '[.name, .title, .version, .manifest, .download] | @csv' "$file" >> "$SYSTEMS_CSV"
done

# === Save JSON versions as arrays ===
jq -s '.' "$MODULES_DIR"/*/module.json > "$MODULES_JSON"
jq -s '.' "$SYSTEMS_DIR"/*/system.json > "$SYSTEMS_JSON"

echo "✅ Metadata snapshot complete:"
echo " - $MODULES_CSV"
echo " - $SYSTEMS_CSV"
echo " - $MODULES_JSON"
echo " - $SYSTEMS_JSON"
