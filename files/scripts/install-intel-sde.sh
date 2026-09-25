#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Intel Software Development Emulator ---"

# --- Configuration -----------------------------------------------------------
SDE_DIR="/opt/intel-sde"
SDE_VERSION="9.44.0"
SDE_DATE="2024-09-25"
SDE_TARBALL="sde-external-${SDE_VERSION}-${SDE_DATE}-lin.tar.xz"

# IMPORTANT: Intel rotates the numeric mirror ID in this URL with every release.
# Verify the current link at:
#   https://www.intel.com/content/www/us/en/developer/articles/tool/software-development-emulator.html
# (look for the "Linux (tar.xz)" download link and copy its URL here)
SDE_URL="https://downloadmirror.intel.com/813591/${SDE_TARBALL}"

# --- Ensure the target directory exists BEFORE cd ----------------------------
mkdir -p "${SDE_DIR}"
cd "${SDE_DIR}"

# --- Use a pre-placed tarball if one exists, otherwise download it ----------
if compgen -G "sde-external-*.tar.xz" > /dev/null; then
    echo "Using pre-placed SDE tarball in ${SDE_DIR}"
else
    echo "Downloading Intel SDE ${SDE_VERSION} (${SDE_DATE})"
    echo "  from ${SDE_URL}"
    if ! curl -fL --retry 3 --retry-delay 5 -o "${SDE_TARBALL}" "${SDE_URL}"; then
        echo "ERROR: Failed to download Intel SDE." >&2
        echo "       The Intel mirror URL has likely rotated." >&2
        echo "       Update SDE_URL in this script from the page above." >&2
        exit 1
    fi
fi

# --- Extract, stripping the top-level directory inside the tarball -----------
tar -xJf sde-external-*.tar.xz --strip-components=1

# --- Clean up the tarball ----------------------------------------------------
rm -f sde-external-*.tar.xz

# --- Make sde / sde64 callable from anywhere ---------------------------------
ln -sf "${SDE_DIR}/sde"   /usr/local/bin/sde
ln -sf "${SDE_DIR}/sde64" /usr/local/bin/sde64

# --- Verify ------------------------------------------------------------------
if [ -x "${SDE_DIR}/sde" ]; then
    echo "Intel SDE installed to ${SDE_DIR}/"
else
    echo "ERROR: Intel SDE installation failed" >&2
    exit 1
fi

echo "--- Intel SDE installation complete ---"
