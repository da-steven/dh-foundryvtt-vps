#!/bin/bash

# === Bootstrap ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"
PLATFORM_UTILS="$UTILS_DIR/platform-utils.sh"
BUILDX_VERSION="v0.11.2"

for helper in "$ENV_LOADER" "$FILE_UTILS" "$PLATFORM_UTILS"; do
  [[ -f "$helper" ]] && source "$helper" || {
    echo "❌ Missing required helper: $helper"
    exit 1
  }
done

MAX_RETRIES=3
FORCE_DOWNLOAD=0
USE_BUILDKIT=0

# === Prompt: Instance Tag (Optional) ===
echo "🔖 Foundry Install: Optional name (e.g. 'main', 'v13')"
read -p "Tag (or leave blank): " TAG
TAG=$(echo "$TAG" | tr -cd '[:alnum:]-')
TAG_SUFFIX=${TAG:+-$TAG}

# === Define Paths ===
INSTALL_DIR="${FOUNDRY_INSTALL_DIR%/}/foundry$TAG_SUFFIX"
DATA_DIR="${FOUNDRY_DATA_DIR%/}/foundry$TAG_SUFFIX"
CONTAINER_NAME="foundryvtt$TAG_SUFFIX"
FOUNDRY_PORT="${FOUNDRY_PORT:-30000}"

echo ""
echo "📁 App Install Dir:     $INSTALL_DIR"
echo "📂 Data Directory:      $DATA_DIR"
echo "🐳 Docker Container:    $CONTAINER_NAME"
echo "🌐 Port:                $FOUNDRY_PORT"
echo ""

read -p "Continue with these settings? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo "⛔ Aborting." && exit 1

# === Existing Container? ===
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "⚠️ Docker container '$CONTAINER_NAME' already exists."
  read -p "Stop and remove it? (y/n): " REMOVE
  [[ "$REMOVE" =~ ^[Yy]$ ]] || exit 1
  docker stop "$CONTAINER_NAME"
  docker rm "$CONTAINER_NAME"
fi

# === Existing Install Directory ===
if [[ -d "$INSTALL_DIR" ]]; then
  if [[ "$(ls -A "$INSTALL_DIR")" ]]; then
    echo "⚠️ Directory $INSTALL_DIR is not empty."
    confirm_overwrite "$INSTALL_DIR" || exit 1
  fi
  sudo rm -rf "$INSTALL_DIR"
fi

# === Backup Data Dir If Non-Empty ===
if [[ -d "$DATA_DIR" && "$(ls -A "$DATA_DIR")" ]]; then
  read -p "Backup existing data directory before continuing? (y/n): " BACKUP
  [[ "$BACKUP" =~ ^[Yy]$ ]] && backup_data_folder "$DATA_DIR" "$(dirname "$DATA_DIR")"
fi

# === Ensure Directories + Disk ===
safe_mkdir "$(dirname "$DATA_DIR")" || exit 1
check_disk_space "$(dirname "$DATA_DIR")" 500 || {
  echo "❌ Not enough disk space for installation. Aborting."
  exit 1
}
safe_mkdir "$INSTALL_DIR" || exit 1
safe_mkdir "$DATA_DIR" || exit 1
sudo chown -R "$USER:$USER" "$INSTALL_DIR" "$DATA_DIR"

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

# === Ensure unzip ===
if ! command -v unzip > /dev/null; then
  echo "📦 Installing unzip..."
  sudo apt install -y unzip || {
    echo "❌ Failed to install unzip. Aborting."
    exit 1
  }
fi

# === Download Foundry ===
cd "$INSTALL_DIR"
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
unzip -q foundryvtt.zip -d "$INSTALL_DIR" && rm foundryvtt.zip
[[ ! -f "$INSTALL_DIR/resources/app/main.mjs" ]] && {
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

# === Dockerfile + Compose ===
echo "🐳 Creating Dockerfile and docker-compose.yml..."
cat <<EOF > "$INSTALL_DIR/Dockerfile"
FROM node:20-slim
WORKDIR /foundry
COPY . /foundry
EXPOSE $FOUNDRY_PORT
CMD ["node", "resources/app/main.mjs", "--dataPath=/data"]
EOF

cat <<EOF > "$INSTALL_DIR/docker-compose.yml"
version: '3.8'
services:
  foundry:
    build: .
    container_name: $CONTAINER_NAME
    ports:
      - "127.0.0.1:$FOUNDRY_PORT:$FOUNDRY_PORT"
    volumes:
      - $DATA_DIR:/data
    restart: unless-stopped
EOF

# === Launch ===
cd "$INSTALL_DIR"
echo "🚀 Starting Foundry container..."
if [[ "$USE_BUILDKIT" -eq 1 ]]; then
  DOCKER_BUILDKIT=1 docker-compose up -d --build
else
  docker-compose up -d --build
fi

[[ $? -ne 0 ]] && {
  echo "❌ Docker container failed to launch."
  docker-compose logs
  exit 1
}

echo ""
echo "✅ Foundry is running!"
echo "🔗 Local URL: http://localhost:$FOUNDRY_PORT"
echo "🎉 Setup complete."