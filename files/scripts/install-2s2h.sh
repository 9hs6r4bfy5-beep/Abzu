#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing 2Ship2Harkinian ---"

REPO="2ship2harkinian/2ship2harkinian"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

echo "Querying latest release from ${REPO}..."
RELEASE_JSON=$(curl -fsSL "${API_URL}")

TAG=$(echo "${RELEASE_JSON}" | jq -r '.tag_name')
echo "Latest release: ${TAG}"

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

# Check the ZIP magic bytes directly. The 'file' utility in this
# container misidentifies some valid archives as 'data', so we look at
# the raw first four bytes instead: a ZIP starts with 'PK\x03\x04'.
echo "Downloaded $(stat -c %s 2s2h.zip) bytes"
FIRST_BYTES=$(od -A n -t x1 -N 4 2s2h.zip | tr -d ' \n')
echo "First 4 bytes: ${FIRST_BYTES}"

if [ "${FIRST_BYTES}" != "504b0304" ]; then
    echo "Error: file does not begin with ZIP magic bytes (got ${FIRST_BYTES})."
    echo "The download may have failed or returned an HTML page."
    exit 1
fi

# Extract. Prefer unzip, fall back to 7z (some archives have extra
# headers that unzip rejects but 7z handles).
EXTRACTED=0
if unzip -o 2s2h.zip >/dev/null 2>&1; then
    EXTRACTED=1
    echo "Extracted with unzip."
elif 7z x -y 2s2h.zip >/dev/null 2>&1; then
    EXTRACTED=1
    echo "Extracted with 7z."
fi

if [ "$EXTRACTED" -ne 1 ]; then
    echo "Could not extract the archive with unzip or 7z."
    echo "Listing of /opt/2s2h:"
    ls -la
    exit 1
fi

rm -f 2s2h.zip

# Locate the AppImage. Use -print -quit so find stops at the first
# match without piping into head (avoids SIGPIPE under pipefail).
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
