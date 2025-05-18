#!/bin/bash

print_title() {
  local TITLE="$1"
  echo ""
  echo "╭──────────────────────────────────────────────╮"
  printf "│ %-44s │\n" "$TITLE"
  echo "╰──────────────────────────────────────────────╯"
}

wait_for_enter() {
  echo ""
  read -rp "Press Enter to continue..." _
}