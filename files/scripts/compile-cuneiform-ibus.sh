#!/usr/bin/env bash
set -euo pipefail

echo "--- Compiling cuneiform IBus table database ---"

TABLE_DIR="/usr/share/ibus-table/tables"
SOURCE="${TABLE_DIR}/ibus-table-cuneiform.txt"
DATABASE="${TABLE_DIR}/ibus-table-cuneiform.db"

if [ ! -f "${SOURCE}" ]; then
    echo "Error: source table not found at ${SOURCE}"
    exit 1
fi

if ! command -v ibus-table-createdb >/dev/null 2>&1; then
    echo "Warning: ibus-table-createdb not found; shipping the .txt only."
    exit 0
fi

ibus-table-createdb -n "${DATABASE}" -s "${SOURCE}"
echo "Created ${DATABASE}"
echo "--- Cuneiform IBus table database compiled ---"