#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing ibus-table-cuneiform ---"

# Clone the ibus-table-cuneiform repository.
git clone --depth 1 https://github.com/srjskam/ibus-table-cuneiform.git /tmp/ibus-cuneiform
cd /tmp/ibus-cuneiform

# --- Oracc sign list workaround ------------------------------------------
# The upstream makefile downloads the Oracc sign list from a URL that no
# longer exists: the repository was renamed from 'ogsl' to 'osl', and
# the file from 'ogsl.asl' to 'osl.asl'. The Python script that consumes
# the file (asl2ibus_table.py) also hardcodes the local filename
# 'ogsl.asl'. We pre-download the current file under that name so that
# make skips its own (broken) download rule.
echo "Pre-downloading the Oracc sign list as ogsl.asl..."
wget -O ogsl.asl.raw \
    https://raw.githubusercontent.com/oracc/osl/master/00lib/osl.asl

if [ ! -s ogsl.asl.raw ]; then
    echo "Failed to download the Oracc sign list."
    exit 1
fi

# The modern Oracc file contains directive lines (starting with '@') and
# blank lines that the old parser in asl2ibus_table.py cannot handle.
# It expects every line to have at least three whitespace-separated
# tokens: 'foo formcode sign ...'. Filter the file to keep only those
# lines before handing it to the parser.
echo "Filtering sign list to lines the parser can handle..."
awk 'NF >= 3' ogsl.asl.raw > ogsl.asl
rm -f ogsl.asl.raw

if [ ! -s ogsl.asl ]; then
    echo "After filtering, the sign list is empty — something is wrong with the upstream file."
    exit 1
fi
echo "Kept $(wc -l < ogsl.asl) sign entries (from $(wc -l < ogsl.asl.raw 2>/dev/null || echo '?') original lines)."
# -------------------------------------------------------------------------

# Build and install. Make sees ogsl.asl is already present and skips its
# own download step. The parser now sees only well-formed lines.
make install

# Clean up.
cd /
rm -rf /tmp/ibus-cuneiform

echo "--- ibus-table-cuneiform installed ---"
