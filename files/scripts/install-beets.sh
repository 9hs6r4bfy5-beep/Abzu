#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Beets via pipx ---"

# pipx is installed via dnf in the recipe.
pipx install --global 'beets[fetchart,lyrics,lastgenre,chroma,web,replaygain]'

echo "--- Beets installed via pipx ---"
echo "Run 'beet config -e' after first login to create your configuration."
