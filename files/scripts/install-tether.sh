#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Tether ---"

# Download the latest AppImage from the GitHub releases page
# Check https://github.com/zackb/tether/releases for the latest version
TETHER_VERSION="0.2.11"
DOWNLOAD_URL="https://github.com/zackb/tether/releases/download/v${TETHER_VERSION}/tether-${TETHER_VERSION}-x86_64.AppImage"

mkdir -p /opt/tether
cd /opt/tether
curl -L -o tether.AppImage "${DOWNLOAD_URL}"
chmod +x tether.AppImage

# Create desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/tether.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Tether
Comment=Bridge your iPhone to Linux
Exec=/opt/tether/tether.AppImage
Icon=phone
Terminal=false
Categories=Network;Utility;
EOF

echo "--- Tether installed to /opt/tether/tether.AppImage ---"
