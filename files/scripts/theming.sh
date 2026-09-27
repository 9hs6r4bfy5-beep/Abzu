#!/usr/bin/env bash
# theming.sh - Installs macOS-inspired themes for a custom Fedora Atomic image.
# Covers Cheetah, Mavericks, Leopard, WhiteSur, and the Liquid Glass GNOME Shell extension.

set -euo pipefail
trap 'echo "theming.sh failed at line $LINENO (exit $?)" >&2' ERR

# Define target directories
THEME_DIR="/usr/share/themes"
ICON_DIR="/usr/share/icons"
GNOME_EXT_DIR="/usr/share/gnome-shell/extensions"

mkdir -p "${THEME_DIR}" "${ICON_DIR}" "${GNOME_EXT_DIR}"

echo "--- Starting Theming Installation ---"

# -----------------------------------------------------------------------------
# 1. B00merang Mac OS X Cheetah theme
# -----------------------------------------------------------------------------
echo "Installing B00merang Mac OS X Cheetah theme..."
wget -q https://github.com/B00merang-Project/Mac-OS-X-Cheetah/archive/master.zip -O /tmp/cheetah.zip
unzip -q /tmp/cheetah.zip -d /tmp/
if [ -d "/tmp/Mac-OS-X-Cheetah-master" ]; then
    mv /tmp/Mac-OS-X-Cheetah-master /tmp/Mac-OS-X-Cheetah
fi
cp -r /tmp/Mac-OS-X-Cheetah "${THEME_DIR}/Mac-OS-X-Cheetah"
rm -rf /tmp/cheetah.zip /tmp/Mac-OS-X-Cheetah

# -----------------------------------------------------------------------------
# 2. B00merang Mavericks theme
# -----------------------------------------------------------------------------
echo "Installing B00merang Mavericks theme..."
wget -q https://github.com/B00merang-Project/OS-X-Mavericks/archive/refs/heads/master.zip -O /tmp/mavericks.zip
unzip -q /tmp/mavericks.zip -d /tmp/
cp -r /tmp/OS-X-Mavericks-master "${THEME_DIR}/OS-X-Mavericks"
rm -rf /tmp/mavericks.zip /tmp/OS-X-Mavericks-master

# -----------------------------------------------------------------------------
# 3. B00merang Leopard theme
# -----------------------------------------------------------------------------
echo "Installing B00merang Leopard theme..."
wget -q https://github.com/B00merang-Project/OS-X-Leopard/archive/refs/heads/master.zip -O /tmp/leopard.zip
unzip -q /tmp/leopard.zip -d /tmp/
cp -r /tmp/OS-X-Leopard-master "${THEME_DIR}/OS-X-Leopard"
rm -rf /tmp/leopard.zip /tmp/OS-X-Leopard-master

# -----------------------------------------------------------------------------
# 4. WhiteSur GTK, icon, and cursor themes (system-wide)
#    Uses the upstream install.sh scripts. Output is NOT silenced so that
#    any failure is visible in the build log.
# -----------------------------------------------------------------------------
echo "Installing WhiteSur theme suite (system-wide)..."

# --- WhiteSur GTK Theme ---
echo "  -> WhiteSur GTK theme"
rm -rf /tmp/whitesur-gtk
if ! git clone --depth 1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/whitesur-gtk; then
    echo "ERROR: Failed to clone WhiteSur-gtk-theme" >&2
    exit 1
fi
if [ ! -f /tmp/whitesur-gtk/install.sh ]; then
    echo "ERROR: install.sh not found in WhiteSur-gtk-theme. Contents:" >&2
    ls -la /tmp/whitesur-gtk >&2
    exit 1
fi
(
    cd /tmp/whitesur-gtk
    echo "    Running: bash install.sh -d ${THEME_DIR} -c dark"
    bash install.sh -d "${THEME_DIR}" -c dark
) || { echo "ERROR: WhiteSur GTK installer failed" >&2; exit 1; }
rm -rf /tmp/whitesur-gtk

# --- WhiteSur Icon Theme ---
echo "  -> WhiteSur icon theme"
rm -rf /tmp/whitesur-icons
if ! git clone --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/whitesur-icons; then
    echo "ERROR: Failed to clone WhiteSur-icon-theme" >&2
    exit 1
fi
(
    cd /tmp/whitesur-icons
    echo "    Running: bash install.sh -d ${ICON_DIR}"
    bash install.sh -d "${ICON_DIR}"
) || { echo "ERROR: WhiteSur icon installer failed" >&2; exit 1; }
rm -rf /tmp/whitesur-icons

# --- WhiteSur Cursors ---
echo "  -> WhiteSur cursors"
rm -rf /tmp/whitesur-cursors
if ! git clone --depth 1 https://github.com/vinceliuice/WhiteSur-cursors.git /tmp/whitesur-cursors; then
    echo "ERROR: Failed to clone WhiteSur-cursors" >&2
    exit 1
fi
(
    cd /tmp/whitesur-cursors
    echo "    Running: bash install.sh -d ${ICON_DIR}"
    bash install.sh -d "${ICON_DIR}"
) || { echo "ERROR: WhiteSur cursor installer failed" >&2; exit 1; }
rm -rf /tmp/whitesur-cursors

echo "WhiteSur theme suite installed."

# -----------------------------------------------------------------------------
# 5. Liquid Glass GNOME Shell Extension
# -----------------------------------------------------------------------------
echo "Installing Liquid Glass GNOME Shell Extension..."
EXT_UUID="liquid-glass@thinkingcoding1231.gmail.com"
rm -rf /tmp/liquid-glass
git clone --depth 1 https://github.com/ryohsuke1231/liquid-glass.git /tmp/liquid-glass
mkdir -p "${GNOME_EXT_DIR}/${EXT_UUID}"
cp -r /tmp/liquid-glass/liquid-glass@thinkingcoding1231.gmail.com/* "${GNOME_EXT_DIR}/${EXT_UUID}/"
rm -rf /tmp/liquid-glass

# -----------------------------------------------------------------------------
# 6. Final Cleanup (safe)
# -----------------------------------------------------------------------------
rm -rf \
    /tmp/cheetah.zip /tmp/Mac-OS-X-Cheetah /tmp/Mac-OS-X-Cheetah-master \
    /tmp/mavericks.zip /tmp/OS-X-Mavericks-master \
    /tmp/leopard.zip /tmp/OS-X-Leopard-master \
    /tmp/liquid-glass \
    2>/dev/null || true

echo "--- Theming Installation Complete ---"
exit 0
