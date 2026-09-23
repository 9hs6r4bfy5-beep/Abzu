#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing pipx and Beets ---"

python3 -m pip install --user pipx
python3 -m pipx ensurepath
~/.local/bin/pipx install --global 'beets[fetchart,lyrics,lastgenre,chroma,web,replaygain]'

echo "--- Beets installed via pipx ---"
echo "Run 'beet config -e' after first login to create your configuration."
