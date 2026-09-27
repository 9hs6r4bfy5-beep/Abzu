#!/usr/bin/env bash
set -euo pipefail

echo "--- Enabling VA-API hardware video encoding ---"

# The default Fedora mesa-va-drivers package is built without the
# patented codecs needed for H.264/HEVC/AV1 hardware encoding. The
# freeworld variant enables them, which is required for OBS Studio
# to offer the VA-API encoder on AMD GPUs.

if rpm -q mesa-va-drivers-freeworld >/dev/null 2>&1; then
    echo "mesa-va-drivers-freeworld already installed."
else
    dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
fi

if rpm -q mesa-vulkan-drivers-freeworld >/dev/null 2>&1; then
    echo "mesa-vulkan-drivers-freeworld already installed."
else
    dnf swap -y mesa-vulkan-drivers mesa-vulkan-drivers-freeworld || true
fi

echo "--- VA-API hardware video encoding enabled ---"
