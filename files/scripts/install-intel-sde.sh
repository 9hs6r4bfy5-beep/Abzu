#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Intel Software Development Emulator ---"

# --- Configuration -----------------------------------------------------------
SDE_DIR="/opt/intel-sde"
SDE_VERSION="9.58.0"
SDE_DATE="2025-06-16"
SDE_TARBALL="sde-external-${SDE_VERSION}-${SDE_DATE}-lin.tar.xz"

# Primary source: Intel's official mirror
SDE_URL="https://downloadmirror.intel.com/859732/${SDE_TARBALL}"

# Fallback source: GitHub mirror (more reliable for automated builds)
SDE_MIRROR_URL="https://github.com/rapidfuzz/intel-sde/releases/download/v${SDE_VERSION}/${SDE_TARBALL}"

# --- Ensure the target directory exists BEFORE cd ----------------------------
mkdir -p "${SDE_DIR}"
cd "${SDE_DIR}"

# --- Try a pre-placed tarball first ------------------------------------------
if compgen -G "sde-external-*.tar.xz" > /dev/null; then
    echo "Using pre-placed SDE tarball in ${SDE_DIR}"
else
    echo "Downloading Intel SDE ${SDE_VERSION} (${SDE_DATE})"

    # Attempt 1: Intel's official mirror
    echo "  Trying Intel mirror: ${SDE_URL}"
    if curl -fL --retry 2 --retry-delay 5 \
         -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36" \
         -o "${SDE_TARBALL}" "${SDE_URL}"; then
        echo "  Downloaded from Intel mirror successfully."
    else
        echo "  Intel mirror failed. Trying GitHub mirror..."
        if curl -fL --retry 3 --retry-delay 5 \
             -o "${SDE_TARBALL}" "${SDE_MIRROR_URL}"; then
            echo "  Downloaded from GitHub mirror successfully."
        else
            echo "ERROR: Failed to download Intel SDE from all sources." >&2
            exit 1
        fi
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
