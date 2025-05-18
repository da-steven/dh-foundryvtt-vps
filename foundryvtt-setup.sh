#!/bin/bash

# === Bootstrap ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
ENV_LOADER="$UTILS_DIR/load-env.sh"
FILE_UTILS="$UTILS_DIR/file-utils.sh"
BUILDX_VERSION="v0.11.2"

# === Load Helpers ===
for helper in "$ENV_LOADER" "$FILE_UTILS"; do
  if [[ -f "$helper" ]]; then
    source "$helper"
  else
    echo "❌ Missing required helper: $helper"
    exit 1
  fi
done

PLATFORM_UTILS="$UTILS_DIR/platform-utils.sh"
if [[ -f "$PLATFORM_UTILS" ]]; then
  source "$PLATFORM_UTILS"
else
  echo "❌ Missing: $PLATFORM_UTILS"
  exit 1
fi

# === Constants ===
MAX_RETRIES=3
USE_BUILDKIT=0
FORCE_DOWNLOAD=0

# === Prompt: Instance Tag ===
echo "🔖 Foundry Install: Please provide a unique tag (e.g. 'main', 'v13', 'dev')"
read -p "Tag: " TAG
TAG=$(echo "$TAG" | tr -cd '[:alnum:]-')
if [[ -z "$TAG" ]]; then
  echo "❌ A valid tag is required."
  exit 1
fi

# === Define Paths ===
INSTALL_DIR="${FOUNDRY_INSTALL_DIR%/}/foundry-$TAG"
DATA_DIR="${FOUNDRY_DATA_DIR%/}/$TAG"
CONTAINER_NAME="foundryvtt-$TAG"
FOUNDRY_PORT="${FOUNDRY_PORT:-30000}"

echo ""
echo "🎯 Instance Tag:        $TAG"
echo "📁 App Install Dir:     $INSTALL_DIR"
echo "📂 Data Directory:      $DATA_DIR"
echo "🐳 Docker Container:    $CONTAINER_NAME"
echo "🌐 Port:                $FOUNDRY_PORT"
echo ""

read -p "Continue with these settings? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo "⛔ Aborting." && exit 1

# === Check for Existing Container ===
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "⚠️ Docker container '$CONTAINER_NAME' already exists."
  read -p "Stop and remove it before proceeding? (y/n): " REMOVE
  if [[ "$REMOVE" =~ ^[Yy]$ ]]; then
    docker stop "$CONTAINER_NAME"
    docker rm "$CONTAINER_NAME"
  else
    echo "⛔ Aborting setup."
    exit 1
  fi
fi

# === Check for Existing Install ===
if [[ -d "$INSTALL_DIR" ]]; then
  echo "⚠️ Directory $INSTALL_DIR already exists."
  confirm_overwrite "$INSTALL_DIR" || exit 1
  sudo rm -rf "$INSTALL_DIR"
fi

# === Optional: Backup Data Directory ===
if [[ -d "$DATA_DIR" ]]; then
  read -p "Backup existing data directory before continuing? (y/n): " BACKUP
  if [[ "$BACKUP" =~ ^[Yy]$ ]]; then
    backup_data_folder "$DATA_DIR" "$(dirname "$DATA_DIR")" || exit 1
  fi
fi

# === Ensure parent directory and check disk space ===
safe_mkdir "$(dirname "$DATA_DIR")" || exit 1
check_disk_space "$(dirname "$DATA_DIR")" 500 || {
  echo "❌ Not enough disk space for installation. Aborting."
  exit 1
}

# === Create Directories ===
safe_mkdir "$INSTALL_DIR" || exit 1
safe_mkdir "$DATA_DIR" || exit 1
sudo chown -R "$USER:$USER" "$INSTALL_DIR" "$DATA_DIR"

# === Install Docker if Needed ===
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
  echo "⚠️ Please log out and back in, or run: newgrp docker"
  newgrp docker
fi

# === Download Foundry ===
cd "$INSTALL_DIR"
if [[ ! -f "foundryvtt.zip" ]]; then
  FORCE_DOWNLOAD=1
fi

if [[ "$FORCE_DOWNLOAD" -eq 1 ]]; then
  while true; do
    read -p "Enter your Foundry VTT timed download URL: " URL
    URL=$(echo "$URL" | xargs)
    echo "📥 Downloading Foundry from:"
    echo "   $URL"
    curl -L --retry $MAX_RETRIES --retry-delay 5 --connect-timeout 10 --max-time 300 -o foundryvtt.zip "$URL"
    if [[ -f "foundryvtt.zip" ]]; then
      echo "✅ Download succeeded."
      break
    else
      echo "❌ Download failed."
      read -p "Try a new URL? (y/n): " TRY_AGAIN
      [[ "$TRY_AGAIN" =~ ^[Yy]$ ]] || exit 1
    fi
  done
else
  echo "📦 Foundry zip already exists."
  read -p "Re-download Foundry? (y/n): " REDOWNLOAD
  if [[ "$REDOWNLOAD" =~ ^[Yy]$ ]]; then
    FORCE_DOWNLOAD=1
    rm -f foundryvtt.zip
    exec "$0" "$@"
  fi
fi

# === Extract Foundry ===
echo "📂 Extracting Foundry..."
unzip -q foundryvtt.zip -d "$INSTALL_DIR" && rm foundryvtt.zip

if [[ ! -f "$INSTALL_DIR/resources/app/main.mjs" ]]; then
  echo "❌ Extraction failed: expected file missing."
  exit 1
fi

# === BuildKit Check ===
if ! docker buildx version > /dev/null 2>&1; then
  echo "⚠️ Docker BuildKit not available. Install now? (y/n): "
  read -p "" INSTALL_BK
  if [[ "$INSTALL_BK" =~ ^[Yy]$ ]]; then
    mkdir -p ~/.docker/cli-plugins
    download_binary_for_arch "$BUILDX_VERSION" "buildx" "$HOME/.docker/cli-plugins/docker-buildx" || {
      echo "❌ BuildKit installation failed."
      read -p "Continue using legacy builder? (y/n): " CONT
      [[ ! "$CONT" =~ ^[Yy]$ ]] && exit 1
    }
    USE_BUILDKIT=1
  else
    echo "⚠️ Continuing with legacy builder."
    USE_BUILDKIT=0
  fi
else
  echo "✅ BuildKit already available."
  USE_BUILDKIT=1
fi

# === Dockerfile and Compose ===
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

# === Launch Container ===
cd "$INSTALL_DIR"
echo "🚀 Building and starting Foundry container..."
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