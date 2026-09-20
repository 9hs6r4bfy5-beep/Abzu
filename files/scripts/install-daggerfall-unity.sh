#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Daggerfall Unity (AppImage) ---"

# Download the latest AppImage from the pkgforge-dev repository
# Check https://github.com/pkgforge-dev/Daggerfall-Unity-AppImage/releases for the latest URL
DFU_VERSION="v1.1.1"
DOWNLOAD_URL="https://github.com/pkgforge-dev/Daggerfall-Unity-AppImage/releases/download/${DFU_VERSION}/Daggerfall.Unity-${DFU_VERSION}-x86_64.AppImage"

mkdir -p /opt/daggerfall-unity
cd /opt/daggerfall-unity
curl -L -o daggerfall-unity.AppImage "${DOWNLOAD_URL}"
chmod +x daggerfall-unity.AppImage

# Create desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/daggerfall-unity.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Daggerfall Unity
Comment=Open source recreation of Daggerfall in the Unity engine
Exec=/opt/daggerfall-unity/daggerfall-unity.AppImage
Icon=daggerfall-unity
Terminal=false
Categories=Game;Roleplaying;
EOF

echo "--- Daggerfall Unity installed ---"
