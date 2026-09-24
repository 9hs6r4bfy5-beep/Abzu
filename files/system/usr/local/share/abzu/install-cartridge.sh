#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing PC Cartridge System components ---"

# Download the launcher helper from the upstream repository.
# The upstream project's helper is a script, not a compiled binary.
mkdir -p /usr/local/share/pc-cartridge
curl -fsSL -o /usr/local/share/pc-cartridge/cartridge-launcher-helper \
    "https://raw.githubusercontent.com/LewdM3at/PC-Cartridge-System/main/linux/cartridge-launcher-helper"
chmod +x /usr/local/share/pc-cartridge/cartridge-launcher-helper

# Install the helper to /usr/local/bin so it is on PATH.
install -m 0755 /usr/local/share/pc-cartridge/cartridge-launcher-helper \
    /usr/local/bin/cartridge-launcher-helper

# Create the trust list directory and seed it with an empty JSON structure.
# The launcher helper reads this file to verify script hashes.
mkdir -p /etc/skel/.config/pc-cartridge
cat > /etc/skel/.config/pc-cartridge/trusted-scripts.json << 'EOF'
{
  "trusted_scripts": []
}
EOF

# Ensure the trust list is not world-writable.
chmod 0600 /etc/skel/.config/pc-cartridge/trusted-scripts.json

# NOTE: The cartridge user creation and usermod commands are intentionally
# omitted here. The cartridge-launch-wrapper detects the active graphical
# user at runtime and runs the helper as that user, so a dedicated system
# user is not needed.

echo "--- PC Cartridge System components installed ---"
