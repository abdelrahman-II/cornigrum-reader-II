#!/bin/bash
# download_assets.sh — CorNigrum Reader Asset & Directory Initializer

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=========================================="
echo "CorNigrum Reader — Asset Initializer"
echo "=========================================="

echo ""
echo "[1/3] Verifying models directory..."
mkdir -p "${PROJECT_ROOT}/assets/models"
touch "${PROJECT_ROOT}/assets/models/.gitkeep"

echo ""
echo "[2/3] Verifying voices directory..."
mkdir -p "${PROJECT_ROOT}/assets/voices"
touch "${PROJECT_ROOT}/assets/voices/.gitkeep"

echo ""
echo "[3/3] Verifying config.json..."
mkdir -p "${PROJECT_ROOT}/assets/config"
if [ ! -f "${PROJECT_ROOT}/assets/config/config.json" ]; then
    echo '{"defaultTheme":"obsidian"}' > "${PROJECT_ROOT}/assets/config/config.json"
fi

echo "Asset initialization complete."

