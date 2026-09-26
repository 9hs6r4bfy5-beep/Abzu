# Compile the cuneiform IBus table database
[group('Cuneiform')]
cuneiform-compile:
    #!/usr/bin/bash
    set -euo pipefail
    SOURCE="/usr/share/ibus-table/tables/ibus-table-cuneiform.txt"
    DATABASE="/usr/share/ibus-table/tables/ibus-table-cuneiform.db"
    if [ ! -f "$SOURCE" ]; then
        echo "Source table not found: $SOURCE"
        exit 1
    fi
    sudo ibus-table-createdb -n "$DATABASE" -s "$SOURCE"
    echo "Cuneiform IBus table compiled."

# Show the cuneiform input method status
[group('Cuneiform')]
cuneiform-status:
    #!/usr/bin/bash
    set -euo pipefail
    echo "--- IBus engines ---"
    ibus list-engine 2>/dev/null | grep -i cuneiform || echo "(cuneiform engine not listed)"
    echo ""
    echo "--- Table files ---"
    ls -la /usr/share/ibus-table/tables/ibus-table-cuneiform.* 2>/dev/null || echo "(no table files)"
    echo ""
    echo "--- Active engine ---"
    ibus engine 2>/dev/null || echo "(ibus-daemon not running)"