#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$SCRIPT_DIR/.env.defaults" ]]; then
  source "$SCRIPT_DIR/.env.defaults"
fi

if [[ -f "$SCRIPT_DIR/.env.local" ]]; then
  source "$SCRIPT_DIR/.env.local"
fi