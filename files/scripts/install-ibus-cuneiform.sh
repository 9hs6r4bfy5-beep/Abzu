#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing ibus-table-cuneiform ---"

# Clone the ibus-table-cuneiform repository.
git clone --depth 1 https://github.com/srjskam/ibus-table-cuneiform.git /tmp/ibus-cuneiform
cd /tmp/ibus-cuneiform

# The upstream makefile hardcodes a URL for the Oracc sign list that has
# since moved. The repository was renamed from 'ogsl' (Oracc Global Sign
# List) to 'osl' (Oracc Sign List), and the file from 'ogsl.asl' to
# 'osl.asl'. Patch the makefile to point at the new location before
# running make, otherwise wget gets a 404 and make aborts.
echo "Patching makefile to use the current Oracc sign list URL..."
sed -i \
    's|https://raw.githubusercontent.com/oracc/ogsl/master/00lib/ogsl.asl|https://raw.githubusercontent.com/oracc/osl/master/00lib/osl.asl|' \
    makefile

# Verify the patch actually applied. If the upstream makefile changes its
# URL format in the future, the sed above may silently do nothing, so we
# check that the old URL is gone and the new one is present.
if grep -q 'oracc/ogsl' makefile; then
    echo "Warning: the makefile still references the old oracc/ogsl URL."
    echo "The sed patch may not have matched. Full makefile:"
    cat makefile
    exit 1
fi

if ! grep -q 'oracc/osl' makefile; then
    echo "Warning: the makefile does not reference the new oracc/osl URL."
    echo "The sed patch may not have matched. Full makefile:"
    cat makefile
    exit 1
fi

echo "makefile patched successfully."

# Build and install the ibus table.
# The makefile needs python3, ibus-table, and jupyter (for nbconvert).
# These are provided by the recipe's dnf module.
make install

# Clean up the build directory.
cd /
rm -rf /tmp/ibus-cuneiform

echo "--- ibus-table-cuneiform installed ---"
