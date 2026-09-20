#!/usr/bin/env bash
set -euo pipefail

echo "--- Building Snow Macintosh Emulator ---"

# Clone the Snow repository
git clone --depth 1 https://github.com/twvd/snow.git /tmp/snow
cd /tmp/snow

# Build in release mode with LTO enabled for a smaller, faster binary
# The BUILDING.md recommends release builds and notes that LTO
# increases compile time but produces a more optimized executable.
CARGO_PROFILE_RELEASE_LTO=fat cargo build -r

# The binary is placed in target/release/snowemu
if [ -f "target/release/snowemu" ]; then
    cp "target/release/snowemu" /usr/local/bin/snowemu
    chmod +x /usr/local/bin/snowemu
    echo "Snow installed to /usr/local/bin/snowemu"
else
    echo "Build failed: snowemu binary not found"
    exit 1
fi

# Create a desktop entry for the GUI
mkdir -p /usr/share/applications
cat > /usr/share/applications/snowemu.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Snow
Comment=Classic Macintosh emulator
Exec=/usr/local/bin/snowemu
Icon=computer
Terminal=false
Categories=System;Emulator;
EOF

# Cleanup
cd /
rm -rf /tmp/snow

echo "--- Snow build complete ---"
