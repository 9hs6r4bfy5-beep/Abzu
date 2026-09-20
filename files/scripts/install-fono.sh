#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Fono binary ---"

# Download the latest CPU or GPU build from GitHub releases
# Use the FONO_VARIANT env var to select: cpu or gpu
FONO_VARIANT="${FONO_VARIANT:-cpu}"

# Fetch the latest release tag
FONO_VERSION=$(curl -fsSL https://api.github.com/repos/bogdanr/fono/releases/latest \
    | grep -oP '"tag_name": "\K[^"]+')

echo "Installing Fono version ${FONO_VERSION} (${FONO_VARIANT} variant)"

# Determine the correct asset name for this architecture
ARCH=$(uname -m)
case "${ARCH}" in
    x86_64) ARCH_TAG="x86_64" ;;
    aarch64) ARCH_TAG="aarch64" ;;
    *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

# The release asset naming convention: fono-${VERSION}-${ARCH}-${VARIANT}.tar.gz
# Adjust this pattern if the upstream naming changes.
ASSET_NAME="fono-${FONO_VERSION#v}-${ARCH_TAG}-${FONO_VARIANT}.tar.gz"
DOWNLOAD_URL="https://github.com/bogdanr/fono/releases/download/${FONO_VERSION}/${ASSET_NAME}"

# Download and extract
mkdir -p /tmp/fono-install
curl -fsSL -o "/tmp/fono-install/${ASSET_NAME}" "${DOWNLOAD_URL}"
tar -xzf "/tmp/fono-install/${ASSET_NAME}" -C /tmp/fono-install

# Install the binary to /usr/local/bin
install -m 0755 /tmp/fono-install/fono /usr/local/bin/fono

# Cleanup
rm -rf /tmp/fono-install

echo "--- Fono binary installed to /usr/local/bin/fono ---"
