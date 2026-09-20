#!/usr/bin/env bash
set -euo pipefail

# Install Hotline Navigator from source
# The Tauri client lives in the hotline-tauri directory of the main repo

echo "--- Building Hotline Navigator ---"

# Clone the repository
git clone --depth 1 https://github.com/fuzzywalrus/hotline.git /tmp/hotline

# Build the Tauri application
cd /tmp/hotline/hotline-tauri

# Install Node.js dependencies
npm install

# Build the production bundle for Linux x86_64
npm run build:linux

# The built binary will be in src-tauri/target/release/
# Copy it to a system location
if [ -f "src-tauri/target/release/hotline-tauri" ]; then
    cp "src-tauri/target/release/hotline-tauri" /usr/local/bin/hotline-navigator
    chmod +x /usr/local/bin/hotline-navigator
    echo "Hotline Navigator installed to /usr/local/bin/hotline-navigator"
else
    echo "Build failed: binary not found"
    exit 1
fi

# Optional: Create a desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/hotline-navigator.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Hotline Navigator
Comment=A modern Hotline client
Exec=/usr/local/bin/hotline-navigator
Icon=internet-web-browser
Terminal=false
Categories=Network;Chat;
EOF

# Cleanup
cd /
rm -rf /tmp/hotline

echo "--- Hotline Navigator build complete ---"
