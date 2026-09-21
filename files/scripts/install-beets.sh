#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing pipx and Beets ---"

# Install pipx system-wide
python3 -m pip install --user pipx
python3 -m pipx ensurepath

# Install Beets with common plugin extras.
# The [fetchart,lyrics,lastgenre,chroma,web] extras pull in dependencies
# for album art fetching, lyrics, genre tagging, acoustic fingerprinting,
# and the web UI.
~/.local/bin/pipx install 'beets[fetchart,lyrics,lastgenre,chroma,web]'

echo "--- Beets installed via pipx ---"
echo "Run 'beet config -e' after first login to create your configuration."
