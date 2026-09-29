#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Super Mario Bros. Remastered ---"

SMB_TAG="1.1-stable"
SMB_ASSET="Linux.zip"
DOWNLOAD_URL="https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/releases/download/${SMB_TAG}/${SMB_ASSET}"

mkdir -p /opt/smb-remastered
cd /opt/smb-remastered

echo "Downloading ${SMB_ASSET} from release ${SMB_TAG}..."
curl -fL -o smb-remastered.bin "${DOWNLOAD_URL}"

# Diagnostics. Use -N 16 so od reads exactly 16 bytes and exits on its
# own; a pipe into `head` would cause SIGPIPE and, under `set -o
# pipefail`, abort the script before extraction runs.
echo "Downloaded $(stat -c %s smb-remastered.bin) bytes"
echo "First 16 bytes:"
od -A x -t x1z -N 16 smb-remastered.bin

# Extract. The archive is a standard ZIP (magic bytes PK\x03\x04), so
# unzip is the natural choice, with 7z as a fallback in case the format
# ever changes.
EXTRACTED=0
if command -v unzip >/dev/null 2>&1 && unzip -o smb-remastered.bin >/dev/null 2>&1; then
    EXTRACTED=1
    echo "Extracted with unzip."
elif command -v 7z >/dev/null 2>&1 && 7z x -y smb-remastered.bin >/dev/null 2>&1; then
    EXTRACTED=1
    echo "Extracted with 7z."
fi

if [ "$EXTRACTED" -ne 1 ]; then
    echo "Could not extract the downloaded archive."
    echo "Contents of /opt/smb-remastered:"
    ls -la
    exit 1
fi

rm -f smb-remastered.bin

# Locate the executable. Use -print -quit to stop at the first match,
# avoiding the head/SIGPIPE problem that bit us in the diagnostics above.
EXEC_PATH=$(find . -maxdepth 3 -type f \
    \( -name "SuperMarioRemastered*" -o -name "SMB1R*" -o -name "*.x86_64" \) \
    -print -quit)

if [ -z "$EXEC_PATH" ]; then
    echo "Could not locate the game executable after extraction."
    echo "Contents of /opt/smb-remastered:"
    find . -maxdepth 3 -type f
    exit 1
fi

chmod +x "$EXEC_PATH"
EXEC_ABS="/opt/smb-remastered/${EXEC_PATH#./}"
echo "Found executable: $EXEC_ABS"

# Create desktop entry.
mkdir -p /usr/share/applications
cat > /usr/share/applications/smb-remastered.desktop << EOF
[Desktop Entry]
Type=Application
Name=Super Mario Bros. Remastered
Comment=A Remake / Celebration of the original Super Mario Bros. games
Exec=$EXEC_ABS
Icon=smb-remastered
Terminal=false
Categories=Game;ActionGame;PlatformGame;
EOF

echo "--- Super Mario Bros. Remastered installed ---"
