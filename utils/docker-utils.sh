#!/bin/bash

# Stop and remove a container if it exists
docker_cleanup() {
  local CONTAINER_NAME="$1"

  if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    echo "🛑 Stopping container: $CONTAINER_NAME"
    docker stop "$CONTAINER_NAME" 2>/dev/null
    docker rm "$CONTAINER_NAME" 2>/dev/null
  fi
}