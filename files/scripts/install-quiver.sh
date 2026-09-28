#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Quiver Launcher (AppImage) ---"

# Quiver Launcher is a single launcher that replaces the five standalone
# installs this image used to ship:
#   * Daggerfall Unity             -> Interkarma/daggerfall-unity            (community catalog)
#   * Ship of Harkinian            -> HarbourMasters/Shipwright              (community catalog)
#   * 2 Ship 2 Harkinian           -> HarbourMasters/2ship2harkinian         (community catalog)
#   * Super Mario Bros. Remastered -> JHDev2006/Super-Mario-Bros.-Remastered-Public (community catalog)
#   * SA Mod Manager               -> not covered; use Flatpak Hedge Mod Manager
# The games themselves are NOT baked into the image any more -- Quiver
# downloads and updates them per user, so the image stays slim.
#
# Deferred (Windows/macOS-only releases, no Linux build yet -- revisit when
# upstream ships one): elliotttate/DKC1Recomp, DKC2Recomp, DKC3Recomp,
# elliotttate/wave-race-64-recomp, DomazinUS/RaceWave46.

REPO="tgeorgiadis/quiver-launcher"
ARCH="$(uname -m)"

case "${ARCH}" in
    x86_64)  ASSET_PATTERN="linux-x64.AppImage" ;;
    aarch64) ASSET_PATTERN="linux-arm64.AppImage" ;;
    *)
        echo "ERROR: Unsupported architecture for Quiver Launcher: ${ARCH}" >&2
        exit 1
        ;;
esac

echo "  Querying latest release of ${REPO} (${ASSET_PATTERN})..."
RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest") || {
    echo "ERROR: Could not query releases for ${REPO}." >&2
    exit 1
}

# Match the AppImage asset for this architecture only. Release filenames are
# stable ("QuiverLauncher-linux-x64.AppImage"), but match on the suffix so an
# upstream version stamp in the name would not break us.
ASSET_URL=$(echo "${RELEASE_JSON}" \
    | jq -r --arg pat "${ASSET_PATTERN}" \
        '.assets[] | select(.name | endswith($pat)) | .browser_download_url' \
    | head -n 1)

if [ -z "${ASSET_URL}" ] || [ "${ASSET_URL}" = "null" ]; then
    echo "ERROR: No '${ASSET_PATTERN}' asset found in the latest release of ${REPO}." >&2
    echo "       Available assets:" >&2
    echo "${RELEASE_JSON}" | jq -r '.assets[].name' >&2 || true
    exit 1
fi

TAG=$(echo "${RELEASE_JSON}" | jq -r '.tag_name')
echo "  Latest release: ${TAG}"
echo "  Downloading: ${ASSET_URL}"

mkdir -p /opt/quiver
cd /opt/quiver
curl -fL -o quiver.AppImage "${ASSET_URL}"
chmod +x quiver.AppImage

# Sanity check: the download must be an ELF binary, not an HTML error page.
FIRST_BYTES=$(od -A n -t x1 -N 4 quiver.AppImage | tr -d ' \n')
if [ "${FIRST_BYTES}" != "7f454c46" ]; then
    echo "ERROR: quiver.AppImage does not start with the ELF magic bytes (got ${FIRST_BYTES})." >&2
    echo "       Downloaded $(stat -c %s quiver.AppImage) bytes; the download probably failed." >&2
    exit 1
fi

# Seed the library with the entries that used to be installed standalone.
# Quiver keeps apps.json beside the AppImage, which is read-only on an
# immutable image, so it falls back to $XDG_DATA_HOME/QuiverLauncher (i.e.
# ~/.local/share/QuiverLauncher). Drop a starter file there via /etc/skel;
# the quiver-setup justfile recipe copies it in place if the user wants it.
mkdir -p /etc/skel/.local/share/quiver
cat > /etc/skel/.local/share/quiver/apps.json << 'EOF'
{
  "apps": [
    {
      "name": "Daggerfall Unity",
      "project": "The Elder Scrolls II: Daggerfall",
      "repository": "Interkarma/daggerfall-unity",
      "folderName": "DaggerfallUnity",
      "tags": ["recreation", "pc", "elder scrolls"],
      "appIconUrl": null
    },
    {
      "name": "Ship of Harkinian",
      "project": "The Legend of Zelda: Ocarina of Time",
      "repository": "HarbourMasters/Shipwright",
      "folderName": "ShipOfHarkinian",
      "tags": ["decomp", "n64", "harbour masters", "zelda"],
      "appIconUrl": null
    },
    {
      "name": "2 Ship 2 Harkinian",
      "project": "The Legend of Zelda: Majora's Mask",
      "repository": "HarbourMasters/2ship2harkinian",
      "folderName": "2Ship2Harkinian",
      "tags": ["decomp", "n64", "harbour masters", "zelda"],
      "appIconUrl": null
    },
    {
      "name": "Super Mario Bros. [Remastered]",
      "project": "Super Mario Bros. Remastered",
      "repository": "JHDev2006/Super-Mario-Bros.-Remastered-Public",
      "folderName": "SuperMarioBrosRemastered-SuperMarioBrosRemastered",
      "tags": ["recreation", "nes", "mario", "nintendo", "nintendo entertainment system"],
      "appIconUrl": "https://raw.githubusercontent.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/main/icon.png"
    }
  ]
}
EOF

# Desktop entry.
# NOTE ON SELF-UPDATE: Quiver ships an in-app updater that rewrites the binary
# next to itself. On an immutable image /opt/quiver is not writable, so the
# updater will fail -- updates arrive by rebuilding this image instead. If you
# would rather have per-user self-updates, drop the AppImage into /etc/skel
# (~/.local/share/QuiverLauncher) and point Exec at that path.
mkdir -p /usr/share/applications
cat > /usr/share/applications/quiver.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Quiver Launcher
Comment=Download, install and update GitHub/GitLab game ports, mods and tools
Exec=/opt/quiver/quiver.AppImage
Icon=applications-games
Terminal=false
Categories=Game;Utility;
Keywords=launcher;mods;github;gitlab;soh;2s2h;daggerfall;mario;
StartupNotify=true
EOF

echo "--- Quiver Launcher installed to /opt/quiver/quiver.AppImage ---"
echo "--- Starter library seeded at /etc/skel/.local/share/quiver/apps.json ---"
