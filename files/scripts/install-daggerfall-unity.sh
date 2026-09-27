#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Daggerfall Unity (AppImage) ---"

REPO="pkgforge-dev/Daggerfall-Unity-AppImage"

echo "  Querying latest release of ${REPO}..."
RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest") || {
    echo "ERROR: Could not query releases for ${REPO}." >&2
    exit 1
}

# Select the first .AppImage asset. The API returns the exact asset name,
# so no filename guessing is required.
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
mkdir -p /opt/daggerfall-unity
cd /opt/daggerfall-unity
curl -fL -o daggerfall-unity.AppImage "${ASSET_URL}"
chmod +x daggerfall-unity.AppImage

# Create desktop entry.
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
