#!/bin/bash

# === Bootstrap Environment ===
# Find and source load-env.sh (it handles finding repo root)
if [[ -f "utils/load-env.sh" ]]; then
  source "utils/load-env.sh"           # We're in repo root
elif [[ -f "../utils/load-env.sh" ]]; then
  source "../utils/load-env.sh"       # We're in subdirectory
else
  echo "❌ Cannot find utils/load-env.sh" >&2
  exit 1
fi

# Load unified configuration and helpers
load_helpers \
  "foundry-config.sh" \
  "file-utils.sh" \
  "platform-utils.sh" \
  "tool-utils.sh"

# === Configuration ===
MAX_RETRIES=3
FORCE_DOWNLOAD=0
USE_BUILDKIT=0
BUILDX_VERSION="v0.11.2"

# Define UID/GID for Docker user mapping
FOUNDRY_UID=$(id -u)
FOUNDRY_GID=$(id -g)

# === Display Configuration ===
echo ""
echo "📁 App Install Dir:     $FOUNDRY_INSTALL_PATH"
echo "📂 Data Directory:      $FOUNDRY_DATA_PATH"
echo "🐳 Docker Container:    $FOUNDRY_CONTAINER_NAME"
echo "🌐 Port:                $FOUNDRY_PORT"
echo "👤 UID:GID:             $FOUNDRY_UID:$FOUNDRY_GID"
echo ""

read -p "Continue with these settings? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo "⛔ Aborting." && exit 1

# === Check for Existing Container ===
if docker ps -a --format '{{.Names}}' | grep -qx "$FOUNDRY_CONTAINER_NAME"; then
  echo "⚠️ Docker container '$FOUNDRY_CONTAINER_NAME' already exists."
  read -p "Stop and remove it? (y/n): " REMOVE
  [[ "$REMOVE" =~ ^[Yy]$ ]] || exit 1
  docker stop "$FOUNDRY_CONTAINER_NAME"
  docker rm "$FOUNDRY_CONTAINER_NAME"
fi

# === Check Existing Install Directory ===
if [[ -d "$FOUNDRY_INSTALL_PATH" && "$(ls -A "$FOUNDRY_INSTALL_PATH")" ]]; then
  echo "⚠️ Directory $FOUNDRY_INSTALL_PATH is not empty."
  confirm_overwrite "$FOUNDRY_INSTALL_PATH" || exit 1
  sudo rm -rf "$FOUNDRY_INSTALL_PATH"
fi

# === Backup Data Directory If Needed ===
if [[ -d "$FOUNDRY_DATA_PATH" && "$(ls -A "$FOUNDRY_DATA_PATH")" ]]; then
  read -p "Backup existing data directory before continuing? (y/n): " BACKUP
  [[ "$BACKUP" =~ ^[Yy]$ ]] && backup_data_folder "$FOUNDRY_DATA_PATH" "$(dirname "$FOUNDRY_DATA_PATH")"
fi

# === Ensure Directories and Check Disk Space ===
safe_mkdir "$(dirname "$FOUNDRY_DATA_PATH")" || exit 1
check_disk_space "$(dirname "$FOUNDRY_DATA_PATH")" 500 || {
  echo "❌ Not enough disk space for installation. Aborting."
  exit 1
}
safe_mkdir "$FOUNDRY_INSTALL_PATH" || exit 1
safe_mkdir "$FOUNDRY_DATA_PATH" || exit 1
sudo chown -R "$USER:$USER" "$FOUNDRY_INSTALL_PATH" "$FOUNDRY_DATA_PATH"

# === Install Docker & Compose ===
if ! command -v docker > /dev/null; then
  echo "📦 Installing Docker..."
  sudo apt update && sudo apt install -y docker.io
fi

if ! command -v docker-compose > /dev/null; then
  echo "📦 Installing Docker Compose..."
  sudo apt install -y docker-compose
fi

sudo systemctl enable --now docker

if ! groups "$USER" | grep -qw docker; then
  echo "👥 Adding $USER to docker group..."
  sudo usermod -aG docker "$USER"
  echo "⏳ Attempting to apply group change..."
  if ! newgrp docker; then
    echo "⚠️ Please log out and back in, or manually run: newgrp docker"
    exit 1
  fi
fi

# === Ensure unzip is installed ===
if ! check_tool unzip && ! install_tool unzip; then
  echo "❌ Failed to install unzip. Aborting."
  exit 1
fi

# === Download Foundry ===
cd "$FOUNDRY_INSTALL_PATH"
[[ ! -f "foundryvtt.zip" ]] && FORCE_DOWNLOAD=1

if [[ "$FORCE_DOWNLOAD" -eq 1 ]]; then
  while true; do
    read -p "Enter your Foundry VTT timed download URL: " URL
    URL=$(echo "$URL" | xargs)
    echo "📥 Downloading Foundry from: $URL"
    curl -L --retry $MAX_RETRIES --retry-delay 5 --connect-timeout 10 --max-time 300 -o foundryvtt.zip "$URL"
    [[ -f "foundryvtt.zip" ]] && break
    echo "❌ Download failed."
    read -p "Try again? (y/n): " TRY
    [[ ! "$TRY" =~ ^[Yy]$ ]] && exit 1
  done
else
  echo "📦 Foundry zip already exists."
  read -p "Re-download Foundry? (y/n): " REDOWNLOAD
  [[ "$REDOWNLOAD" =~ ^[Yy]$ ]] && { rm -f foundryvtt.zip; exec "$0" "$@"; }
fi

# === Extract Foundry ===
echo "📂 Extracting Foundry..."
unzip -q foundryvtt.zip -d "$FOUNDRY_INSTALL_PATH" && rm foundryvtt.zip
[[ ! -f "$FOUNDRY_INSTALL_PATH/resources/app/main.mjs" ]] && {
  echo "❌ Extraction failed: expected file missing."
  exit 1
}

# === Docker BuildKit ===
if ! docker buildx version > /dev/null 2>&1; then
  echo "⚠️ BuildKit not found. Install now? (y/n): "
  read -p "" INSTALL_BK
  if [[ "$INSTALL_BK" =~ ^[Yy]$ ]]; then
    mkdir -p ~/.docker/cli-plugins
    download_binary_for_arch "$BUILDX_VERSION" "buildx" "$HOME/.docker/cli-plugins/docker-buildx" || {
      echo "❌ BuildKit install failed."
      read -p "Continue with legacy builder? (y/n): " CONT
      [[ ! "$CONT" =~ ^[Yy]$ ]] && exit 1
    }
    USE_BUILDKIT=1
  fi
else
  echo "✅ BuildKit available."
  USE_BUILDKIT=1
fi

# === Create Dockerfile and Docker Compose ===
echo "🐳 Creating Dockerfile and docker-compose.yml..."
cat <<EOF > "$FOUNDRY_INSTALL_PATH/Dockerfile"
FROM node:20-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl \
      wget \
      iputils-ping \
      nano \
      vim \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /foundry
COPY . /foundry
EXPOSE $FOUNDRY_PORT
CMD ["node", "resources/app/main.mjs", "--dataPath=/data"]
EOF

cat <<EOF > "$FOUNDRY_INSTALL_PATH/docker-compose.yml"
version: '3.8'
services:
  foundry:
    build: .
    container_name: $FOUNDRY_CONTAINER_NAME
    user: "${FOUNDRY_UID}:${FOUNDRY_GID}"
    ports:
      - "127.0.0.1:$FOUNDRY_PORT:$FOUNDRY_PORT"
    volumes:
      - $FOUNDRY_DATA_PATH:/data
    restart: unless-stopped
EOF

# === Launch Container ===
cd "$FOUNDRY_INSTALL_PATH"
echo "🚀 Starting Foundry container..."
if [[ "$USE_BUILDKIT" -eq 1 ]]; then
  DOCKER_BUILDKIT=1 docker-compose up -d --build
else
  docker-compose up -d --build
fi

if [[ $? -ne 0 ]]; then
  echo "❌ Docker container failed to launch."
  docker-compose logs
  exit 1
fi

echo ""
echo "✅ Foundry is running!"
echo "🔗 Local URL: http://localhost:$FOUNDRY_PORT"
echo "🎉 Setup complete."