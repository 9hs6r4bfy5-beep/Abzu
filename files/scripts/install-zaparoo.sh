#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Zaparoo Core ---"

# The official installer is a script that downloads the correct binary for
# your architecture and sets up the systemd user service.
# It is designed to be safe for immutable systems by installing to ~/.local.
# Download the Zaparoo binary directly
ZAPAROO_VERSION=$(curl -fsSL https://api.github.com/repos/ZaparooProject/zaparoo-core/releases/latest \
    | grep -oP '"tag_name": "v\K[^"]+') # Check https://github.com/ZaparooProject/zaparoo-core/releases for latest
ARCH=$(uname -m)
case "${ARCH}" in
    x86_64) ARCH_TAG="amd64" ;;
    aarch64) ARCH_TAG="arm64" ;;
    *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

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
