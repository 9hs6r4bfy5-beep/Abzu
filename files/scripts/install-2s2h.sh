#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing 2Ship2Harkinian ---"

REPO="2ship2harkinian/2ship2harkinian"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

echo "Querying latest release from ${REPO}..."
RELEASE_JSON=$(curl -fsSL "${API_URL}")

TAG=$(echo "${RELEASE_JSON}" | jq -r '.tag_name')
echo "Latest release: ${TAG}"

# Find the asset whose name ends with '-Linux.zip'. This is robust to
# the release codename changing between versions (Battler Bravo,
# Rena Alfa, etc.).
ASSET_URL=$(echo "${RELEASE_JSON}" \
    | jq -r '.assets[] | select(.name | endswith("-Linux.zip")) | .browser_download_url')

if [ -z "${ASSET_URL}" ] || [ "${ASSET_URL}" = "null" ]; then
    echo "Error: no Linux asset found in release ${TAG}."
    echo "Assets available:"
    echo "${RELEASE_JSON}" | jq -r '.assets[].name'
    exit 1
fi

echo "Downloading ${ASSET_URL}..."
mkdir -p /opt/2s2h
cd /opt/2s2h
curl -fL -o 2s2h.zip "${ASSET_URL}"

# Verify we actually received a zip archive.
if ! file 2s2h.zip | grep -qi 'zip archive'; then
    echo "Downloaded file is not a zip archive."
    file 2s2h.zip || true
    exit 1
fi

echo "Extracting archive..."
unzip -o 2s2h.zip
rm -f 2s2h.zip

# Locate the AppImage inside the archive. Use -print -quit so we stop
# at the first match without piping into head (which under pipefail
# would abort the script on SIGPIPE).
APPIMAGE=$(find . -maxdepth 3 -type f \
    \( -name '*.appimage' -o -name '*.AppImage' \) \
    -print -quit)

if [ -z "${APPIMAGE}" ]; then
    echo "Error: no AppImage found in the extracted archive."
    echo "Contents of /opt/2s2h:"
    ls -la
    exit 1
fi

chmod +x "${APPIMAGE}"
APPIMAGE_ABS="/opt/2s2h/${APPIMAGE#./}"
echo "Found AppImage: ${APPIMAGE_ABS}"

# Create desktop entry.
mkdir -p /usr/share/applications
cat > /usr/share/applications/2ship2harkinian.desktop << EOF
[Desktop Entry]
Type=Application
Name=2 Ship 2 Harkinian
Comment=PC port of The Legend of Zelda: Majora's Mask
Exec=${APPIMAGE_ABS}
Icon=2ship2harkinian
Terminal=false
Categories=Game;ActionGame;
EOF

echo "--- 2Ship2Harkinian installed ---"
