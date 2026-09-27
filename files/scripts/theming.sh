#!/usr/bin/env bash
# theming.sh - Installs macOS-inspired themes for a custom Fedora Atomic image.
# Covers Cheetah, Mavericks, Leopard, WhiteSur, and the Liquid Glass GNOME Shell extension.

set -euo pipefail

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
#    Uses the official pre-built release archives instead of the installer.
#    This avoids the installer's dependency checks and network calls.
# -----------------------------------------------------------------------------
echo "Installing WhiteSur theme suite (system-wide)..."

# --- WhiteSur GTK Theme (dark) ---
echo "  -> WhiteSur GTK theme (dark)"
curl -fL -o /tmp/whitesur-gtk-dark.tar.xz \
    "https://github.com/vinceliuice/WhiteSur-gtk-theme/releases/latest/download/WhiteSur-Dark.tar.xz"
tar -xJf /tmp/whitesur-gtk-dark.tar.xz -C "${THEME_DIR}"
rm -f /tmp/whitesur-gtk-dark.tar.xz

# --- WhiteSur GTK Theme (light) ---
echo "  -> WhiteSur GTK theme (light)"
curl -fL -o /tmp/whitesur-gtk-light.tar.xz \
    "https://github.com/vinceliuice/WhiteSur-gtk-theme/releases/latest/download/WhiteSur-Light.tar.xz"
tar -xJf /tmp/whitesur-gtk-light.tar.xz -C "${THEME_DIR}"
rm -f /tmp/whitesur-gtk-light.tar.xz

# --- WhiteSur Icon Theme ---
echo "  -> WhiteSur icon theme"
curl -fL -o /tmp/whitesur-icons.tar.xz \
    "https://github.com/vinceliuice/WhiteSur-icon-theme/releases/latest/download/WhiteSur.tar.xz"
tar -xJf /tmp/whitesur-icons.tar.xz -C "${ICON_DIR}"
rm -f /tmp/whitesur-icons.tar.xz

# --- WhiteSur Cursors ---
echo "  -> WhiteSur cursors"
curl -fL -o /tmp/whitesur-cursors.tar.xz \
    "https://github.com/vinceliuice/WhiteSur-cursors/releases/latest/download/WhiteSur-cursors.tar.xz"
tar -xJf /tmp/whitesur-cursors.tar.xz -C "${ICON_DIR}"
rm -f /tmp/whitesur-cursors.tar.xz

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
