#!/usr/bin/env bash
set -euo pipefail

echo "--- Building Apple II Pi ---"

echo "  Diagnostic: FUSE headers present:"
ls -la /usr/include/fuse* 2>/dev/null || echo "    (none)"
rpm -qa | grep -i fuse || echo "    No 'fuse*' RPMs installed"

# Apple2Pi includes an optional FUSE filesystem (fusea2pi) that links
# against FUSE 2 (libfuse). On recent Fedora, the FUSE 2 development
# headers may not be installable, in which case we skip that target.
# The core utilities (a2joy, a2joymou, a2joypad, a2mon, a2term) build
# with nothing more than a C compiler and standard headers.

rm -rf /tmp/apple2pi
if ! git clone --depth 1 https://github.com/dschmenk/apple2pi.git /tmp/apple2pi; then
    echo "ERROR: Failed to clone Apple2Pi" >&2
    exit 1
fi

cd /tmp/apple2pi

# Decide whether FUSE 2 headers are available.
FUSE2_OK=false
if [ -f /usr/include/fuse.h ]; then
    FUSE2_OK=true
elif [ -f /usr/include/fuse/fuse.h ]; then
    # Some distributions put the header under a subdirectory and rely on
    # the Makefile's -I/usr/include/fuse flag to find it.
    FUSE2_OK=true
fi

if [ "$FUSE2_OK" = true ]; then
    echo "  FUSE 2 headers found; building all targets."
else
    echo "  FUSE 2 headers not found; skipping optional 'fusea2pi' target."
    echo "  Headers checked: /usr/include/fuse.h, /usr/include/fuse/fuse.h"
    # Remove fusea2pi from the Makefile's ALL variable and from any
    # dependency lists, so 'make' and 'make install' do not attempt it.
    # We edit a copy and only replace whole-word occurrences.
    sed -i 's/\bfusea2pi\b//g' Makefile
fi

make
make install

echo "--- Apple II Pi built ---"
