#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing PC Cartridge System components ---"

# Only download the helper if it is not already present.
if [ ! -f /usr/local/bin/cartridge-launcher-helper ]; then
    echo "Downloading cartridge-launcher-helper from upstream..."
    mkdir -p /usr/local/share/pc-cartridge
    curl -fsSL -o /usr/local/share/pc-cartridge/cartridge-launcher-helper \
        "https://raw.githubusercontent.com/LewdM3at/PC-Cartridge-System/main/linux/cartridge-launcher-helper"
    install -m 0755 /usr/local/share/pc-cartridge/cartridge-launcher-helper \
        /usr/local/bin/cartridge-launcher-helper
fi

# Create the trust list directory and seed it with an empty JSON structure.
mkdir -p /etc/skel/.config/pc-cartridge
cat > /etc/skel/.config/pc-cartridge/trusted-scripts.json << 'EOF'
{
  "trusted_scripts": []
}
EOF
chmod 0600 /etc/skel/.config/pc-cartridge/trusted-scripts.json

echo "--- PC Cartridge System components installed ---"
