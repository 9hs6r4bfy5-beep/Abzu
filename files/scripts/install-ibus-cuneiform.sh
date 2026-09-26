#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing ibus-table-cuneiform ---"

# Clone the ibus-table-cuneiform repository.
git clone --depth 1 https://github.com/srjskam/ibus-table-cuneiform.git /tmp/ibus-cuneiform
cd /tmp/ibus-cuneiform

# --- Oracc sign list workaround ------------------------------------------
# The upstream makefile downloads the Oracc sign list from a URL that no
# longer exists: the repository was renamed from 'ogsl' (Oracc Global
# Sign List) to 'osl' (Oracc Sign List), and the file from 'ogsl.asl' to
# 'osl.asl'. Additionally, the Python script that consumes the file
# (asl2ibus_table.py) hardcodes the local filename 'ogsl.asl' on line 9.
#
# Patching only the URL is not enough: wget saves files under the URL's
# basename, so we would end up with 'osl.asl' on disk while the Python
# script looks for 'ogsl.asl'. The cleanest fix is to pre-download the
# current file ourselves, saving it under the name the Python script
# expects. Make then skips its own download rule because the target
# already exists.
echo "Pre-downloading the Oracc sign list as ogsl.asl..."
wget -O ogsl.asl \
    https://raw.githubusercontent.com/oracc/osl/master/00lib/osl.asl

if [ ! -s ogsl.asl ]; then
    echo "Failed to download the Oracc sign list."
    exit 1
fi
echo "Downloaded $(wc -l < ogsl.asl) lines of sign data."
# -------------------------------------------------------------------------

# Build and install. The makefile will see ogsl.asl is already present
# and skip its own (broken) download step.
make install

# Clean up.
cd /
rm -rf /tmp/ibus-cuneiform

echo "--- ibus-table-cuneiform installed ---"
