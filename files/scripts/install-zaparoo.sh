#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Zaparoo Core ---"

# Zaparoo's Linux releases are named by distribution, not by "linux".
# For Atomic Fedora (which Bazzite and Abzu both are), the bazzite
# build is the appropriate asset.

DOWNLOAD_URL=$(curl -fsSL \
    https://api.github.com/repos/ZaparooProject/zaparoo-core/releases/latest \
    | jq -r '.assets[] | select(.name | contains("bazzite_amd64")) | .browser_download_url')

if [ -z "${DOWNLOAD_URL}" ]; then
    echo "ERROR: Could not find the bazzite_amd64 asset for the latest release."
    exit 1
fi

echo "Downloading: ${DOWNLOAD_URL}"

# Download and extract the tarball.
mkdir -p /tmp/zaparoo-install
cd /tmp/zaparoo-install
curl -fsSL -o zaparoo.tar.gz "${DOWNLOAD_URL}"
tar -xzf zaparoo.tar.gz

# The tarball contains the zaparoo binary. Find it and install it.
ZAPAROO_BIN=$(find /tmp/zaparoo-install -type f -name "zaparoo" | head -n 1)

if [ -z "${ZAPAROO_BIN}" ]; then
    echo "ERROR: Could not find the zaparoo binary in the tarball."
    exit 1
fi

install -m 0755 "${ZAPAROO_BIN}" /usr/local/bin/zaparoo

# Clean up.
rm -rf /tmp/zaparoo-install

# Verify the installation.
if [ -x /usr/local/bin/zaparoo ]; then
    echo "Zaparoo Core installed successfully to /usr/local/bin/zaparoo"
else
    echo "Installation failed: zaparoo binary not found."
    exit 1
fi

echo "--- Zaparoo Core installation complete ---"
echo "--- Run 'ujust zaparoo-setup' after first login to install the user service. ---"
