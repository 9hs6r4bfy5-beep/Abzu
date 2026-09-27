#!/usr/bin/env bash
# theming.sh - Installs macOS-inspired themes for a custom Fedora Atomic image.

set -euo pipefail

trap 'echo "theming.sh failed at line $LINENO (exit $?)" >&2' ERR

THEME_DIR="/usr/share/themes"
ICON_DIR="/usr/share/icons"
GNOME_EXT_DIR="/usr/share/gnome-shell/extensions"

mkdir -p "${THEME_DIR}" "${ICON_DIR}" "${GNOME_EXT_DIR}"

echo "--- Starting Theming Installation ---"

# -----------------------------------------------------------------------------
# 1. B00merang themes (pre-compiled, no installer needed)
# -----------------------------------------------------------------------------
echo "Installing B00merang Mac OS X Cheetah theme..."
wget -q https://github.com/B00merang-Project/Mac-OS-X-Cheetah/archive/master.zip -O /tmp/cheetah.zip
unzip -q /tmp/cheetah.zip -d /tmp/
if [ -d "/tmp/Mac-OS-X-Cheetah-master" ]; then
    mv /tmp/Mac-OS-X-Cheetah-master /tmp/Mac-OS-X-Cheetah
fi
cp -r /tmp/Mac-OS-X-Cheetah "${THEME_DIR}/Mac-OS-X-Cheetah"
rm -rf /tmp/cheetah.zip /tmp/Mac-OS-X-Cheetah

echo "Installing B00merang Mavericks theme..."
wget -q https://github.com/B00merang-Project/OS-X-Mavericks/archive/refs/heads/master.zip -O /tmp/mavericks.zip
unzip -q /tmp/mavericks.zip -d /tmp/
cp -r /tmp/OS-X-Mavericks-master "${THEME_DIR}/OS-X-Mavericks"
rm -rf /tmp/mavericks.zip /tmp/OS-X-Mavericks-master

echo "Installing B00merang Leopard theme..."
wget -q https://github.com/B00merang-Project/OS-X-Leopard/archive/refs/heads/master.zip -O /tmp/leopard.zip
unzip -q /tmp/leopard.zip -d /tmp/
cp -r /tmp/OS-X-Leopard-master "${THEME_DIR}/OS-X-Leopard"
rm -rf /tmp/leopard.zip /tmp/OS-X-Leopard-master

# -----------------------------------------------------------------------------
# 2. WhiteSur GTK theme — download full source tarball (not shallow clone)
# -----------------------------------------------------------------------------
echo "Installing WhiteSur GTK theme..."

WHITESUR_GTK_URL="https://github.com/vinceliuice/WhiteSur-gtk-theme/archive/refs/heads/master.tar.gz"
rm -rf /tmp/whitesur-gtk /tmp/whitesur-gtk.tar.gz

if ! curl -fsSL -o /tmp/whitesur-gtk.tar.gz "${WHITESUR_GTK_URL}"; then
    echo "ERROR: Failed to download WhiteSur GTK theme tarball" >&2
    exit 1
fi

mkdir -p /tmp/whitesur-gtk
if ! tar -xzf /tmp/whitesur-gtk.tar.gz -C /tmp/whitesur-gtk --strip-components=1; then
    echo "ERROR: Failed to extract WhiteSur GTK tarball" >&2
    exit 1
fi
rm -f /tmp/whitesur-gtk.tar.gz

# Diagnostic: verify the installer exists and has content
echo "  Diagnostic: install.sh size = $(stat -c %s /tmp/whitesur-gtk/install.sh 2>/dev/null || echo 'MISSING') bytes"
echo "  Diagnostic: install.sh first line = $(head -1 /tmp/whitesur-gtk/install.sh 2>/dev/null || echo 'N/A')"
echo "  Diagnostic: libs/ directory = $(ls /tmp/whitesur-gtk/libs/ 2>/dev/null | tr '\n' ' ' || echo 'MISSING')"
echo "  Diagnostic: REPO_DIR would resolve to $(cd /tmp/whitesur-gtk && readlink -m install.sh 2>/dev/null || echo 'READLINK FAILED')"

# Patch the dependency check in libs/lib-install.sh (if it exists)
if [ -f /tmp/whitesur-gtk/libs/lib-install.sh ]; then
    sed -i '/DEPS ERROR/ s/exit 1/:/' /tmp/whitesur-gtk/libs/lib-install.sh
    echo "  Patched dependency check in libs/lib-install.sh"
fi

# Run the installer with stderr visible
echo "  Running: bash install.sh -d ${THEME_DIR} -c dark"
if ! (
    cd /tmp/whitesur-gtk
    bash install.sh -d "${THEME_DIR}" -c dark 2>&1
); then
    echo "ERROR: WhiteSur GTK installer failed (exit $?)" >&2
    echo "  install.sh content preview:" >&2
    head -30 /tmp/whitesur-gtk/install.sh >&2 || true
    exit 1
fi
rm -rf /tmp/whitesur-gtk

# -----------------------------------------------------------------------------
# 3. WhiteSur icon theme — download full source tarball
# -----------------------------------------------------------------------------
echo "Installing WhiteSur icon theme..."

WHITESUR_ICON_URL="https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/heads/master.tar.gz"
rm -rf /tmp/whitesur-icons /tmp/whitesur-icons.tar.gz

if ! curl -fsSL -o /tmp/whitesur-icons.tar.gz "${WHITESUR_ICON_URL}"; then
    echo "ERROR: Failed to download WhiteSur icon theme tarball" >&2
    exit 1
fi

mkdir -p /tmp/whitesur-icons
if ! tar -xzf /tmp/whitesur-icons.tar.gz -C /tmp/whitesur-icons --strip-components=1; then
    echo "ERROR: Failed to extract WhiteSur icon tarball" >&2
    exit 1
fi
rm -f /tmp/whitesur-icons.tar.gz

echo "  Running: bash install.sh -d ${ICON_DIR}"
if ! (
    cd /tmp/whitesur-icons
    bash install.sh -d "${ICON_DIR}" 2>&1
); then
    echo "ERROR: WhiteSur icon installer failed (exit $?)" >&2
    exit 1
fi
rm -rf /tmp/whitesur-icons

# -----------------------------------------------------------------------------
# 4. WhiteSur cursors — download full source tarball
# -----------------------------------------------------------------------------
echo "Installing WhiteSur cursors..."

WHITESUR_CURSOR_URL="https://github.com/vinceliuice/WhiteSur-cursors/archive/refs/heads/master.tar.gz"
rm -rf /tmp/whitesur-cursors /tmp/whitesur-cursors.tar.gz

if ! curl -fsSL -o /tmp/whitesur-cursors.tar.gz "${WHITESUR_CURSOR_URL}"; then
    echo "ERROR: Failed to download WhiteSur cursor tarball" >&2
    exit 1
fi

mkdir -p /tmp/whitesur-cursors
if ! tar -xzf /tmp/whitesur-cursors.tar.gz -C /tmp/whitesur-cursors --strip-components=1; then
    echo "ERROR: Failed to extract WhiteSur cursor tarball" >&2
    exit 1
fi
rm -f /tmp/whitesur-cursors.tar.gz

echo "  Running: bash install.sh -d ${ICON_DIR}"
if ! (
    cd /tmp/whitesur-cursors
    bash install.sh -d "${ICON_DIR}" 2>&1
); then
    echo "ERROR: WhiteSur cursor installer failed (exit $?)" >&2
    exit 1
fi
rm -rf /tmp/whitesur-cursors

echo "WhiteSur theme suite installed."

# -----------------------------------------------------------------------------
# 5. Liquid Glass GNOME Shell Extension
# -----------------------------------------------------------------------------
echo "Installing Liquid Glass GNOME Shell Extension..."
EXT_UUID="liquid-glass@thinkingcoding1231.gmail.com"
rm -rf /tmp/liquid-glass
if ! git clone --depth 1 https://github.com/ryohsuke1231/liquid-glass.git /tmp/liquid-glass; then
    echo "ERROR: Failed to clone liquid-glass" >&2
    exit 1
fi
mkdir -p "${GNOME_EXT_DIR}/${EXT_UUID}"
cp -r /tmp/liquid-glass/liquid-glass@thinkingcoding1231.gmail.com/* "${GNOME_EXT_DIR}/${EXT_UUID}/"
rm -rf /tmp/liquid-glass

# -----------------------------------------------------------------------------
# 6. Final cleanup
# -----------------------------------------------------------------------------
rm -rf \
    /tmp/cheetah.zip /tmp/Mac-OS-X-Cheetah /tmp/Mac-OS-X-Cheetah-master \
    /tmp/mavericks.zip /tmp/OS-X-Mavericks-master \
    /tmp/leopard.zip /tmp/OS-X-Leopard-master \
    /tmp/liquid-glass \
    2>/dev/null || true

echo "--- Theming Installation Complete ---"
exit 0
