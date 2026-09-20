#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing 2Ship2Harkinian (AppImage) ---"

2S2H_VERSION="5.0.1"
DOWNLOAD_URL="https://github.com/HarbourMasters/2ship2harkinian/releases/download/${2S2H_VERSION}/2ship.appimage"

mkdir -p /opt/2s2h
cd /opt/2s2h
curl -L -o 2ship.appimage "${DOWNLOAD_URL}"
chmod +x 2ship.appimage

# Create desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/2ship2harkinian.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=2 Ship 2 Harkinian
Comment=PC port of The Legend of Zelda: Majora's Mask
Exec=/opt/2s2h/2ship.appimage
Icon=2ship2harkinian
Terminal=false
Categories=Game;ActionGame;
EOF

echo "--- 2Ship2Harkinian installed ---"
