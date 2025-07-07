#!/bin/bash
# tools/list-instances.sh - List all Foundry VTT instances

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

# Load unified configuration and helpers
load_helpers \
  "foundry-config.sh" 

# === Configuration ===
MODE="table"  # default output
if [[ "$1" == "--json" ]]; then
  MODE="json"
elif [[ "$1" == "--quiet" ]]; then
  MODE="quiet"
fi

# === Collection Array for JSON ===
declare -a INSTANCE_LIST

# === Functions ===
print_table_header() {
  echo ""
  echo "╭──────────────────────────────────────────────╮"
  echo "│ 📋 Listing Foundry Instances"
  echo "╰──────────────────────────────────────────────╯"
  echo ""
  printf "%-10s │ %-30s │ %-30s │ %-15s │ %s\n" "Tag" "Install Folder" "Data Folder" "Container" "Status"
  printf "%s\n" "$(printf '─%.0s' {1..120})"
}

print_table_row() {
  printf "%-10s │ %-30s │ %-30s │ %-15s │ %s\n" "$1" "$2" "$3" "$4" "$5"
}

append_json_row() {
  INSTANCE_LIST+=("{\"tag\":\"$1\",\"install\":\"$2\",\"data\":\"$3\",\"container\":\"$4\",\"status\":\"$5\"}")
}

print_quiet_row() {
  echo "$1"
}

# === Main Logic ===
found_any=false
[[ "$MODE" == "table" ]] && print_table_header

# Look for foundry-* directories in install base
for dir in "$FOUNDRY_INSTALL_DIR"/foundry-*; do
  [[ -d "$dir" ]] || continue
  
  # Extract tag from directory name (foundry-v12 -> v12)
  tag="${dir##*/foundry-}"
  [[ "$tag" == "*" ]] && continue  # Skip if no matches
  
  install_path="$dir"
  data_path="${FOUNDRY_DATA_DIR}/foundry-${tag}"
  container_name="foundryvtt-$tag"
  
  # Get container status
  status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
  [[ -z "$status" ]] && status="not created"

  case "$MODE" in
    table)
      print_table_row "$tag" "$(basename "$install_path")" "$(basename "$data_path")" "$container_name" "$status"
      ;;
    json)
      append_json_row "$tag" "$install_path" "$data_path" "$container_name" "$status"
      ;;
    quiet)
      print_quiet_row "$tag"
      ;;
  esac

  found_any=true
done

# Output JSON
if [[ "$MODE" == "json" ]]; then
  if [[ "$found_any" == true ]]; then
    printf '[\n  %s\n]\n' "$(IFS=,; echo "${INSTANCE_LIST[*]}")"
  else
    echo "[]"
  fi
fi

# No installs case (only for table mode)
if [[ "$found_any" == false && "$MODE" == "table" ]]; then
  echo "⚠️ No Foundry installs detected in: $FOUNDRY_INSTALL_DIR"
fi

[[ "$MODE" == "table" ]] && echo ""