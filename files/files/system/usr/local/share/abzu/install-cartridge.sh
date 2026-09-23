#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing PC Cartridge System components ---"

# Download the launcher helper from the upstream repository
mkdir -p /usr/local/share/pc-cartridge
curl -fsSL -o /usr/local/share/pc-cartridge/cartridge-launcher-helper \
    "https://raw.githubusercontent.com/LewdM3at/PC-Cartridge-System/main/linux/cartridge-launcher-helper"
chmod +x /usr/local/share/pc-cartridge/cartridge-launcher-helper
install -m 0755 /usr/local/share/pc-cartridge/cartridge-launcher-helper \
    /usr/local/bin/cartridge-launcher-helper

# Create a dedicated system user for the launcher service.
# The user needs access to mounted removable media.
if ! id -u cartridge >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin cartridge
fi

# Add the cartridge user to the plugdev group so it can access mounts.
# On Fedora, removable media is typically mounted with the user's UID,
# so the service may also need to run as the primary user.
# Adjust this to match your automount configuration.
usermod -aG plugdev cartridge 2>/dev/null || true

# Install the launcher helper.
# Extract this from the upstream project's linux/ directory.
install -m 0755 /usr/local/share/pc-cartridge/cartridge-launcher-helper /usr/local/bin/cartridge-launcher-helper

# Create the trust list directory and seed it with a valid JSON structure.
# The launcher helper reads this file to verify script hashes.
mkdir -p /etc/skel/.config/pc-cartridge
cat > /etc/skel/.config/pc-cartridge/trusted-scripts.json << 'EOF'
{
  "trusted_scripts": []
}
EOF

# Ensure the trust list is not world-writable.
chmod 0600 /etc/skel/.config/pc-cartridge/trusted-scripts.json

echo "--- PC Cartridge System installed ---"
