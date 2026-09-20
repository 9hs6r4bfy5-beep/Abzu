#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing ibus-table-cuneiform ---"

git clone --depth 1 https://github.com/srjskam/ibus-table-cuneiform.git /tmp/ibus-cuneiform
cd /tmp/ibus-cuneiform
make install
cd /
rm -rf /tmp/ibus-cuneiform

echo "--- ibus-table-cuneiform installed ---"
