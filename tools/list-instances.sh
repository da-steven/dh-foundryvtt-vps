#!/bin/bash

# === Bootstrap environment ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
source "$UTILS_DIR/load-env.sh"
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"

if [[ -f "$ENV_LOADER" ]]; then
  source "$ENV_LOADER"
else
  echo "❌ Missing: $ENV_LOADER"
  exit 1
fi

if [[ -f "$FILE_UTILS" ]]; then
  source "$FILE_UTILS"
else
  echo "❌ Missing: $FILE_UTILS"
  exit 1
fi

# === Config ===
INSTALL_BASE="${FOUNDRY_INSTALL_DIR:-/opt/FoundryVTT}"
DATA_BASE="${FOUNDRY_DATA_DIR:-$HOME/FoundryVTT-Data}"

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

for dir in "$INSTALL_BASE"/foundry-*; do
  [[ -d "$dir" ]] || continue
  tag="${dir##*/foundry-}"
  install_path="$dir"
  data_path="${DATA_BASE}-${tag}"
  container_name="foundryvtt-$tag"
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
  echo "⚠️ No Foundry installs detected in: $INSTALL_BASE"
fi

[[ "$MODE" == "table" ]] && echo ""