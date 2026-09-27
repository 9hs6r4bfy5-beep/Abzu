#!/usr/bin/env bash
set -euo pipefail

echo "--- Building Apple II Pi (with FUSE 3 fusea2pi) ---"

# -----------------------------------------------------------------------------
# Verify that FUSE 3 development headers are present. They are provided by
# the `fuse3-devel` package, which is installed via the dnf module.
# -----------------------------------------------------------------------------
if [ ! -f /usr/include/fuse3/fuse.h ]; then
    echo "ERROR: FUSE 3 header /usr/include/fuse3/fuse.h not found." >&2
    echo "       Ensure 'fuse3-devel' is installed via the dnf module." >&2
    exit 1
fi
echo "  FUSE 3 header found: /usr/include/fuse3/fuse.h"
echo "  pkg-config fuse3: $(pkg-config --modversion fuse3 2>/dev/null || echo 'not found')"

# -----------------------------------------------------------------------------
# Clone Apple2Pi.
# -----------------------------------------------------------------------------
rm -rf /tmp/apple2pi
if ! git clone --depth 1 https://github.com/dschmenk/apple2pi.git /tmp/apple2pi; then
    echo "ERROR: Failed to clone Apple2Pi" >&2
    exit 1
fi

cd /tmp/apple2pi

# -----------------------------------------------------------------------------
# Replace the upstream fusea2pi.c and Makefile with our FUSE 3 versions.
# These are stored in the image at /tmp/files/apple2pi/ because the
# `files` module copies the repository's files/ directory into /tmp/files.
# -----------------------------------------------------------------------------
FUSEA2PI_SRC="/tmp/files/apple2pi/fusea2pi.c"
MAKEFILE_SRC="/tmp/files/apple2pi/Makefile"

if [ ! -f "$FUSEA2PI_SRC" ]; then
    echo "ERROR: Ported fusea2pi.c not found at $FUSEA2PI_SRC" >&2
    exit 1
fi
if [ ! -f "$MAKEFILE_SRC" ]; then
    echo "ERROR: Ported Makefile not found at $MAKEFILE_SRC" >&2
    exit 1
fi

cp "$FUSEA2PI_SRC" /tmp/apple2pi/src/fusea2pi.c
cp "$MAKEFILE_SRC" /tmp/apple2pi/src/Makefile
echo "  Replaced src/fusea2pi.c and src/Makefile with FUSE 3 versions"

# -----------------------------------------------------------------------------
# Build. The Makefile builds all targets, including fusea2pi.
# -----------------------------------------------------------------------------
echo "  Building..."
make -C src

# -----------------------------------------------------------------------------
# Verify that fusea2pi was actually produced and links against FUSE 3.
# -----------------------------------------------------------------------------
if [ ! -x /tmp/apple2pi/src/fusea2pi ]; then
    echo "ERROR: fusea2pi was not produced by the build." >&2
    ls -la /tmp/apple2pi/src/ >&2
    exit 1
fi

echo "  fusea2pi built successfully."
echo "  Linked libraries:"
ldd /tmp/apple2pi/src/fusea2pi | grep -E 'fuse|pthread' || true

# -----------------------------------------------------------------------------
# Install.
# -----------------------------------------------------------------------------
echo "  Installing..."
make -C src install

echo "--- Apple II Pi built and installed (fusea2pi included) ---"
