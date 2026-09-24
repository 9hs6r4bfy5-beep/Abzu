#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Intel Software Development Emulator ---"

# The tarball is pre-placed in the image at /opt/intel-sde/.
# Extract it in place.
cd /opt/intel-sde
tar -xJf sde-external-*.tar.xz --strip-components=1
rm -f sde-external-*.tar.xz

# Create a symlink so sde is available on PATH.
ln -sf /opt/intel-sde/sde /usr/local/bin/sde

if [ -x /opt/intel-sde/sde ]; then
    echo "Intel SDE installed to /opt/intel-sde/"
else
    echo "ERROR: Intel SDE installation failed"
    exit 1
fi

echo "--- Intel SDE installation complete ---"
