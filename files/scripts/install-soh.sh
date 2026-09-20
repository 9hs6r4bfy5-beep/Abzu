#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Ship of Harkinian (AppImage) ---"

# Download the latest AppImage from the official releases
# Check https://github.com/HarbourMasters/Shipwright/releases for the latest URL
SOH_VERSION="9.0.0"
DOWNLOAD_URL="https://github.com/HarbourMasters/Shipwright/releases/download/${SOH_VERSION}/ShipofHarkinian.AppImage"

mkdir -p /opt/soh
cd /opt/soh
curl -L -o ship-of-harkinian.AppImage "${DOWNLOAD_URL}"
chmod +x ship-of-harkinian.AppImage

# Create desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/ship-of-harkinian.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Ship of Harkinian
Comment=PC port of The Legend of Zelda: Ocarina of Time
Exec=/opt/soh/ship-of-harkinian.AppImage
Icon=ship-of-harkinian
Terminal=false
Categories=Game;ActionGame;
EOF

echo "--- Ship of Harkinian installed ---"
