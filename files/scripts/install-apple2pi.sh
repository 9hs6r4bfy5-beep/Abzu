#!/usr/bin/env bash
set -euo pipefail

echo "--- Building Apple II Pi ---"

# Clone the repository
git clone --depth 1 https://github.com/dschmenk/apple2pi.git /tmp/apple2pi
cd /tmp/apple2pi/src

# Build the daemon and tools
make

# Install to /usr/local/bin
make install

# Build and install the FUSE driver for ProDOS disk images
cd /tmp/apple2pi
make fusea2pi
make fuse-install

# Cleanup
cd /
rm -rf /tmp/apple2pi

echo "--- Apple II Pi installed ---"
