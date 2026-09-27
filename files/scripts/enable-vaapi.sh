#!/usr/bin/env bash
set -euo pipefail

echo "--- Enabling VA-API hardware video encoding ---"

# Fedora 44 removed the mesa-va-drivers sub-package. The VAAPI backend
# moved back into mesa-dri-drivers, which ships with the base image.
#
# The old RPM Fusion method:
#     dnf swap mesa-va-drivers mesa-va-drivers-freeworld
# no longer works. It pulls mesa-dri-drivers from the updates-archive
# repository, whose snapshot is incomplete and produces:
#     nothing provides mesa-filesystem(x86-64) = ... needed by mesa-dri-drivers
#
# The correct approach for Fedora 44+ is the "parallel installation method":
# install mesa-va-drivers-freeworld alongside the Fedora Mesa packages,
# without swapping. See https://rpmfusion.org/CommonBugs
# (Fedora 44 → Drop mesa-va-drivers).

# Disable updates-archive. It is a downgrade-only repository that Fedora
# ships disabled by default. Enabling it allows dnf to select an incomplete
# historical snapshot of Mesa, which cannot be resolved.
DNF_OPTS=(--disablerepo=updates-archive)

# --- VAAPI freeworld (patented codecs for H.264/HEVC/AV1 encoding) ---
if rpm -q mesa-va-drivers-freeworld >/dev/null 2>&1; then
    echo "  mesa-va-drivers-freeworld already installed."
else
    echo "  Installing mesa-va-drivers-freeworld..."
    dnf install -y "${DNF_OPTS[@]}" mesa-va-drivers-freeworld
fi

# --- Vulkan freeworld (optional; non-fatal if unavailable) ---
if rpm -q mesa-vulkan-drivers-freeworld >/dev/null 2>&1; then
    echo "  mesa-vulkan-drivers-freeworld already installed."
else
    echo "  Installing mesa-vulkan-drivers-freeworld..."
    dnf install -y "${DNF_OPTS[@]}" mesa-vulkan-drivers-freeworld || true
fi

echo "--- VA-API hardware video encoding enabled ---"
