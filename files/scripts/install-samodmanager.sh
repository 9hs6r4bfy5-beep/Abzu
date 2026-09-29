#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Sonic Adventure Mod Manager ---"

# The installer is designed to run as a regular user, in a graphical
# session. On an Atomic/immutable system we cannot run it at build time,
# so we clone the installer repo into a system location and drop a
# desktop launcher into /etc/skel/Desktop. The user runs the launcher
# once after first login.

INSTALLER_DIR="/usr/local/share/sa-modmanager-installer"
REPO_URL="https://github.com/alexankitty/sa-modmanager-installer-linux.git"

# Clone the installer repository.
rm -rf "${INSTALLER_DIR}"
mkdir -p "$(dirname "${INSTALLER_DIR}")"
if ! git clone --depth 1 "${REPO_URL}" "${INSTALLER_DIR}"; then
    echo "ERROR: Failed to clone ${REPO_URL}" >&2
    exit 1
fi

# Verify the expected scripts are present before chmod'ing them, so a
# future rename in the upstream repo produces a clear error rather than
# an obscure "No such file" from chmod.
for script in SAModManagerSetupImmutable.sh SADXConvertImmutable.sh; do
    if [ ! -f "${INSTALLER_DIR}/${script}" ]; then
        echo "ERROR: Expected script not found: ${INSTALLER_DIR}/${script}" >&2
        echo "Contents of ${INSTALLER_DIR}:" >&2
        ls -la "${INSTALLER_DIR}" >&2 || true
        exit 1
    fi
done

chmod +x "${INSTALLER_DIR}/SAModManagerSetupImmutable.sh"
chmod +x "${INSTALLER_DIR}/SADXConvertImmutable.sh"

# Create a desktop launcher that runs the installer in the user's session.
# OnlyShowIn=GNOME; restricts the launcher to GNOME, matching the desktop
# environment that Abzu ships.
mkdir -p /etc/skel/Desktop
cat > /etc/skel/Desktop/Install-SA-Mod-Manager.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Install Sonic Adventure Mod Manager
Comment=Set up SA Mod Manager on this system
Exec=bash -c 'cd /usr/local/share/sa-modmanager-installer && ./SAModManagerSetupImmutable.sh && notify-send "SA Mod Manager installation complete"'
Icon=applications-games
Terminal=true
Categories=Game;
OnlyShowIn=GNOME;
EOF

chmod +x /etc/skel/Desktop/Install-SA-Mod-Manager.desktop

echo "--- SA Mod Manager installer staged ---"
echo "Run the 'Install Sonic Adventure Mod Manager' desktop launcher after first login."
