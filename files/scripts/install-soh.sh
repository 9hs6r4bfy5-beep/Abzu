#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Ship of Harkinian ---"

REPO="HarbourMasters/Shipwright"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

echo "Querying latest release from ${REPO}..."
RELEASE_JSON=$(curl -fsSL "${API_URL}")

TAG=$(echo "${RELEASE_JSON}" | jq -r '.tag_name')
echo "Latest release: ${TAG}"

# The release asset is a .zip archive named like 'SoH-Ackbar-Delta-Linux.zip'.
# Select the first asset ending in '-Linux.zip' (case-insensitive).
ASSET_URL=$(echo "${RELEASE_JSON}" \
    | jq -r '.assets[] | select(.name | test("-Linux\\.zip$"; "i")) | .browser_download_url' \
    | head -n 1)

if [ -z "${ASSET_URL}" ] || [ "${ASSET_URL}" = "null" ]; then
    echo "Error: no Linux .zip asset found in release ${TAG}." >&2
    echo "Assets available:" >&2
    echo "${RELEASE_JSON}" | jq -r '.assets[].name' >&2
    exit 1
fi

echo "Downloading ${ASSET_URL}..."
mkdir -p /opt/soh
cd /opt/soh
curl -fL -o soh.zip "${ASSET_URL}"

echo "Downloaded $(stat -c %s soh.zip) bytes"

# Extract. Prefer unzip, fall back to 7z.
EXTRACTED=0
if unzip -o soh.zip >/dev/null 2>&1; then
    EXTRACTED=1
    echo "Extracted with unzip."
elif 7z x -y soh.zip >/dev/null 2>&1; then
    EXTRACTED=1
    echo "Extracted with 7z."
fi

if [ "$EXTRACTED" -ne 1 ]; then
    echo "Could not extract the archive with unzip or 7z." >&2
    echo "Listing of /opt/soh:" >&2
    ls -la >&2
    exit 1
fi

rm -f soh.zip

# Locate the AppImage. Use -print -quit so find stops at the first match.
APPIMAGE=$(find . -maxdepth 3 -type f \
    \( -name '*.appimage' -o -name '*.AppImage' \) \
    -print -quit)

if [ -z "${APPIMAGE}" ]; then
    echo "Error: no AppImage found in the extracted archive." >&2
    echo "Contents of /opt/soh:" >&2
    ls -la >&2
    exit 1
fi

chmod +x "${APPIMAGE}"
APPIMAGE_ABS="/opt/soh/${APPIMAGE#./}"
echo "Found AppImage: ${APPIMAGE_ABS}"

# Create desktop entry.
mkdir -p /usr/share/applications
cat > /usr/share/applications/ship-of-harkinian.desktop << EOF
[Desktop Entry]
Type=Application
Name=Ship of Harkinian
Comment=PC port of The Legend of Zelda: Ocarina of Time
Exec=${APPIMAGE_ABS}
Icon=ship-of-harkinian
Terminal=false
Categories=Game;ActionGame;
EOF

echo "--- Ship of Harkinian installed ---"
