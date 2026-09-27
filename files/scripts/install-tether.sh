#!/usr/bin/env bash
set -euo pipefail
echo "--- Installing Tether ---"

REPO="zackb/tether"

echo "  Querying latest release of ${REPO}..."
RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest") || {
    echo "ERROR: Could not query releases for ${REPO}." >&2
    exit 1
}

# Extract the download URL of the first .AppImage asset in the release.
# This avoids guessing the filename, which varies by project.
ASSET_URL=$(echo "$RELEASE_JSON" \
    | jq -r '.assets[] | select(.name | test("\\.AppImage$"; "i")) | .browser_download_url' \
    | head -n 1)

if [ -z "$ASSET_URL" ] || [ "$ASSET_URL" = "null" ]; then
    echo "ERROR: No .AppImage asset found in the latest release of ${REPO}." >&2
    echo "       Available assets:" >&2
    echo "$RELEASE_JSON" | jq -r '.assets[].name' >&2 || true
    exit 1
fi

echo "  Downloading: ${ASSET_URL}"
mkdir -p /opt/tether
cd /opt/tether
curl -fL -o tether.AppImage "${ASSET_URL}"
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
