#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Zaparoo Core ---"

# The official installer is a script that downloads the correct binary for
# your architecture and sets up the systemd user service.
# It is designed to be safe for immutable systems by installing to ~/.local.
curl -fsSL https://zaparoo.org/install.sh | bash

# The installer places the binary in ~/.local/bin.
# We need to make sure this path is available. On Atomic Fedora, ~/.local/bin
# is typically already in the PATH for user shells.

# Verify the installation
if [ -f "${HOME}/.local/bin/zaparoo" ]; then
    echo "Zaparoo Core installed successfully to ${HOME}/.local/bin"
else
    echo "Installation failed: zaparoo binary not found."
    exit 1
fi

echo "--- Zaparoo Core installation complete ---"
