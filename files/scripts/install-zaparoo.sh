#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Zaparoo Core ---"

# The official installer is a script that downloads the correct binary for
# your architecture and sets up the systemd user service.
# It is designed to be safe for immutable systems by installing to ~/.local.
# Download the Zaparoo binary directly
DOWNLOAD_URL=$(curl -fsSL https://api.github.com/repos/ZaparooProject/zaparoo-core/releases/latest \
    | jq -r '.assets[] | select(.name | contains("linux") and contains("amd64")) | .browser_download_url')
curl -fsSL -o /usr/local/bin/zaparoo "${DOWNLOAD_URL}"

curl -fsSL -o /usr/local/bin/zaparoo \
    "https://github.com/ZaparooProject/zaparoo-core/releases/download/v${ZAPAROO_VERSION}/zaparoo_${ZAPAROO_VERSION}_linux_${ARCH_TAG}"
chmod +x /usr/local/bin/zaparoo

# The Zaparoo binary is installed to /usr/local/bin so it is available
# system-wide. The user service is set up separately via a ujust command.

# Verify the installation
if [ -x /usr/local/bin/zaparoo ]; then
    echo "Zaparoo Core installed successfully to /usr/local/bin/zaparoo"
else
    echo "Installation failed: zaparoo binary not found."
    exit 1
fi

echo "--- Zaparoo Core installation complete ---"
