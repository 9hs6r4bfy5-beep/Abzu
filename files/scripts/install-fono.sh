#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Fono ---"

# Select CPU (default) or GPU build. The GPU build requires a Vulkan-capable
# driver at runtime; the CPU build runs everywhere.
FONO_VARIANT="${FONO_VARIANT:-cpu}"

# Map the machine architecture to the tag used in release asset names.
ARCH=$(uname -m)
case "${ARCH}" in
    x86_64) ARCH_TAG="x86_64" ;;
    aarch64) ARCH_TAG="aarch64" ;;
    *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

# Fetch the latest release tag from the GitHub API.
# jq is available in the build environment (it is in the recipe's dnf list).
FONO_TAG=$(curl -fsSL https://api.github.com/repos/bogdanr/fono/releases/latest \
    | jq -r '.tag_name')

if [ -z "${FONO_TAG}" ] || [ "${FONO_TAG}" = "null" ]; then
    echo "Failed to determine the latest Fono release tag."
    exit 1
fi

echo "Installing Fono ${FONO_TAG} (${FONO_VARIANT} variant, ${ARCH_TAG})"

# The release assets are BARE BINARIES, not archives.
#   CPU: fono-vX.Y.Z-<arch>
#   GPU: fono-gpu-vX.Y.Z-<arch>
# Note the full tag (including the leading 'v') is part of the filename.
case "${FONO_VARIANT}" in
    cpu) ASSET_NAME="fono-${FONO_TAG}-${ARCH_TAG}" ;;
    gpu) ASSET_NAME="fono-gpu-${FONO_TAG}-${ARCH_TAG}" ;;
    *) echo "Unknown FONO_VARIANT: ${FONO_VARIANT} (expected 'cpu' or 'gpu')"; exit 1 ;;
esac

DOWNLOAD_URL="https://github.com/bogdanr/fono/releases/download/${FONO_TAG}/${ASSET_NAME}"

# Download the binary.
mkdir -p /tmp/fono-install
if ! curl -fL "${DOWNLOAD_URL}" -o "/tmp/fono-install/fono"; then
    echo "Download failed: ${DOWNLOAD_URL}"
    exit 1
fi

# Sanity check: must be a 64-bit ELF binary. Catches a bad download or a
# future change to the asset naming with a clear error.
if ! file "/tmp/fono-install/fono" | grep -q 'ELF 64-bit'; then
    echo "Downloaded file is not a valid 64-bit ELF binary:"
    file "/tmp/fono-install/fono" || true
    exit 1
fi

# Install to /usr/local/bin. Use 'install' rather than 'cp' so the mode
# is set atomically and the result is owned by root.
install -m 0755 /tmp/fono-install/fono /usr/local/bin/fono
rm -rf /tmp/fono-install

echo "--- Fono installed to /usr/local/bin/fono ---"

# Desktop entry so Fono appears in the application menu.
mkdir -p /usr/share/applications
cat > /usr/share/applications/fono.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Fono
Comment=Local-first voice dictation and assistant
Exec=/usr/local/bin/fono
Icon=audio-input-microphone
Terminal=true
Categories=Utility;Audio;
EOF
