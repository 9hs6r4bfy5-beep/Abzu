#!/usr/bin/env bash
set -euo pipefail

echo "--- Preconfiguring Stellarium sky culture ---"

# Target the user skeleton directory so new users inherit the setting.
# The path mirrors the Flatpak sandbox structure:
#   ~/.var/app/org.stellarium.Stellarium/config/Stellarium/
SKEL_CONFIG_DIR="/etc/skel/.var/app/org.stellarium.Stellarium/config/Stellarium"

mkdir -p "${SKEL_CONFIG_DIR}"

# Write a minimal config.ini that sets the Babylonian (MUL.APIN) sky culture.
# Stellarium will merge this with its internal defaults on first run.
cat > "${SKEL_CONFIG_DIR}/config.ini" << 'EOF'
[localization]
sky_culture = babylonian_mulapin
EOF

echo "Stellarium sky culture preconfigured to babylonian_mulapin"
