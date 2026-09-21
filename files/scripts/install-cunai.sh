#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing CunAI ---"

# Linux x64 AppImage — confirmed URL
CUNAI_URL="https://artifacts.cunai.app/latest/cunai.AppImage"

mkdir -p /opt/cunai
cd /opt/cunai
curl -L -o cunai.AppImage "${CUNAI_URL}"
chmod +x cunai.AppImage

echo "--- CunAI AppImage installed to /opt/cunai/cunai.AppImage ---"
echo "--- On first launch, the app will download the embedding model ---"
