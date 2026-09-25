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

# Diagnostic logging so that if the format ever surprises us again, the
# log tells us exactly what we received.
echo "Downloaded $(stat -c %s smb-remastered.bin) bytes"
echo "Detected type: $(file -b smb-remastered.bin)"
echo "First 16 bytes:"
od -A x -t x1z -v smb-remastered.bin | head -1

# Extract using whichever tool matches the actual format.
# 7z (from p7zip, already in the recipe) handles zip, tar, gzip, xz,
# zstd, 7z, rar, bzip2, and more. unzip is the fallback.
EXTRACTED=0
if 7z x -y smb-remastered.bin >/dev/null 2>&1; then
    EXTRACTED=1
    echo "Extracted with 7z."
elif unzip -o smb-remastered.bin >/dev/null 2>&1; then
    EXTRACTED=1
    echo "Extracted with unzip."
fi

if [ "$EXTRACTED" -ne 1 ]; then
    echo "Could not extract the downloaded archive with 7z or unzip."
    echo "The download itself succeeded; the archive format is the problem."
    echo "Contents of /opt/smb-remastered:"
    ls -la
    exit 1
fi

rm -f smb-remastered.bin

# The executable name and layout vary between builds. Search the first
# two directory levels for anything that looks like the game binary.
EXEC_PATH=$(find . -maxdepth 3 -type f \
    \( -name "SuperMarioRemastered*" -o -name "SMB1R*" -o -name "*.x86_64" \) \
    | head -1)

if [ -z "$EXEC_PATH" ]; then
    echo "Could not locate the game executable after extraction."
    echo "Contents of /opt/smb-remastered:"
    find . -maxdepth 3 -type f | head -40
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
