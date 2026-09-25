#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Super Mario Bros. Remastered ---"

# Current stable release tag and asset name.
# Check https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/releases
# if this ever stops working.
SMB_TAG="1.1-stable"
SMB_ASSET="Linux.zip"
DOWNLOAD_URL="https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/releases/download/${SMB_TAG}/${SMB_ASSET}"

mkdir -p /opt/smb-remastered
cd /opt/smb-remastered

echo "Downloading ${SMB_ASSET} from release ${SMB_TAG}..."
if ! curl -fL -o smb-remastered.zip "${DOWNLOAD_URL}"; then
    echo "Download failed: ${DOWNLOAD_URL}"
    exit 1
fi

# Verify we actually received a zip archive (the previous failure
# downloaded a 9-byte stub, which unzip could not open).
if ! file smb-remastered.zip | grep -qi 'zip archive'; then
    echo "Downloaded file is not a valid zip archive:"
    file smb-remastered.zip || true
    echo "Size: $(stat -c %s smb-remastered.zip) bytes"
    exit 1
fi

unzip -o smb-remastered.zip
rm smb-remastered.zip

# Find the Linux executable. Depending on the build, the binary may be
# named either SuperMarioRemastered.x86_64 or SMB1R.x86_64.
EXEC_PATH=""
for candidate in \
    "SuperMarioRemastered.x86_64" \
    "SMB1R.x86_64" \
    "SuperMarioRemastered" \
    "SMB1R"
do
    if [ -f "$candidate" ]; then
        EXEC_PATH="$candidate"
        break
    fi
done

if [ -z "$EXEC_PATH" ]; then
    echo "Could not locate the game executable. Contents of /opt/smb-remastered:"
    ls -la
    exit 1
fi

chmod +x "$EXEC_PATH"
echo "Found executable: /opt/smb-remastered/$EXEC_PATH"

# Create desktop entry.
mkdir -p /usr/share/applications
cat > /usr/share/applications/smb-remastered.desktop << EOF
[Desktop Entry]
Type=Application
Name=Super Mario Bros. Remastered
Comment=A Remake / Celebration of the original Super Mario Bros. games
Exec=/opt/smb-remastered/$EXEC_PATH
Icon=smb-remastered
Terminal=false
Categories=Game;ActionGame;PlatformGame;
EOF

echo "--- Super Mario Bros. Remastered installed ---"
