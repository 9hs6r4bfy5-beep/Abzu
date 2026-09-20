#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Sonic Adventure Mod Manager ---"

# The installer is designed to run as a regular user.
# If this script runs as root during the build, we need to target the user's home.
# For a first-login approach, this script should be run by the user.

# For the image build, we will clone the repo and place the installer
# where the user can easily access it.

INSTALLER_DIR="/usr/local/share/sa-modmanager-installer"

# Clone the repository (or download the zip) during the build
git clone --depth 1 https://github.com/alexankitty/sa-modmanager-installer-linux.git "${INSTALLER_DIR}"

# Make the scripts executable
chmod +x "${INSTALLER_DIR}/SAModManagerSetupImmutable.sh"
chmod +x "${INSTALLER_DIR}/SADXConvertImmutable.sh"

# Create a desktop launcher that runs the installer on first use.
# This is the most practical approach for an Atomic system.
# The user clicks the launcher, and the script runs in their user context.

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
EOF

chmod +x /etc/skel/Desktop/Install-SA-Mod-Manager.desktop

echo "--- SA Mod Manager installer staged ---"
echo "Run the 'Install Sonic Adventure Mod Manager' desktop launcher after first login."
