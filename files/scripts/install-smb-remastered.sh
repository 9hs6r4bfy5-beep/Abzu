#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Super Mario Bros. Remastered ---"

SMB_VERSION="1.1-rc4"
DOWNLOAD_URL="https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/releases/download/${SMB_VERSION}/SuperMarioBrosRemastered-Linux.zip"

mkdir -p /opt/smb-remastered
cd /opt/smb-remastered
curl -L -o smb-remastered.zip "${DOWNLOAD_URL}"
unzip -o smb-remastered.zip
rm smb-remastered.zip

# Find the executable and make it executable
chmod +x SuperMarioRemastered.x86_64 2>/dev/null || true

# Create desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/smb-remastered.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Super Mario Bros. Remastered
Comment=A Remake / Celebration of the original Super Mario Bros. games
Exec=/opt/smb-remastered/SuperMarioRemastered.x86_64
Icon=smb-remastered
Terminal=false
Categories=Game;ActionGame;PlatformGame;
EOF

echo "--- Super Mario Bros. Remastered installed ---"
