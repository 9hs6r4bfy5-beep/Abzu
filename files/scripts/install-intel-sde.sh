#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Intel Software Development Emulator ---"

# Intel's download mirror now uses a bot challenge that blocks curl.
# Use the GitHub mirror maintained by the rapidfuzz project instead.
SDE_VERSION="10.13.1"
SDE_DATE="2026-07-28"
SDE_ARCHIVE="sde-external-${SDE_VERSION}-${SDE_DATE}-lin.tar.xz"
SDE_URL="https://github.com/BasedInc/sde/releases/download/v10.13.1/sde-external-10.13.1-2026-07-28-lin.tar.xz"

# Download and extract
mkdir -p /opt/intel-sde
cd /tmp
curl -fsSL -o "${SDE_ARCHIVE}" "${SDE_URL}"
tar -xJf "${SDE_ARCHIVE}" -C /opt/intel-sde --strip-components=1
rm -f "${SDE_ARCHIVE}"

# Create a symlink so sde is available on PATH
ln -sf /opt/intel-sde/sde /usr/local/bin/sde

# Verify the installation
if [ -x /opt/intel-sde/sde ]; then
    echo "Intel SDE installed to /opt/intel-sde/"
    /opt/intel-sde/sde --version 2>/dev/null | head -n 1 || true
else
    echo "ERROR: Intel SDE installation failed"
    exit 1
fi

echo "--- Intel SDE installation complete ---"
