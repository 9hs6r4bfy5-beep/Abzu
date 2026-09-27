#!/usr/bin/env bash
# theming.sh - Installs macOS-inspired themes for a custom Fedora Atomic image.
# Covers Cheetah, Mavericks, Leopard, WhiteSur, and the Liquid Glass GNOME Shell extension.

set -euo pipefail

# Print the exact line number if anything fails, for easier debugging
trap 'echo "theming.sh failed at line $LINENO (exit $?)" >&2' ERR

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
# 4. WhiteSur GTK theme (dark + light)
#    Downloads pre-compiled archives from the repository's stable-release/
#    directory. These are committed to Git, not attached to GitHub releases.
#    If the stable archives are unavailable, falls back to cloning the source
#    and running install.sh with the network check patched out.
# -----------------------------------------------------------------------------
echo "Installing WhiteSur GTK theme..."

WHITESUR_GTK_REPO="https://github.com/vinceliuice/WhiteSur-gtk-theme"

install_whitesur_gtk_from_stable() {
    local variant="$1"   # "Dark" or "Light"
    local url="${WHITESUR_GTK_REPO}/raw/master/stable-release/WhiteSur-${variant}.tar.xz"
    echo "  -> WhiteSur GTK theme (${variant,,}) [stable archive]"
    if curl -fsSL -o "/tmp/whitesur-${variant,,}.tar.xz" "$url"; then
        tar -xJf "/tmp/whitesur-${variant,,}.tar.xz" -C "${THEME_DIR}"
        rm -f "/tmp/whitesur-${variant,,}.tar.xz"
        return 0
    fi
    return 1
}

install_whitesur_gtk_from_source() {
    echo "  -> WhiteSur GTK theme [source fallback]"
    rm -rf /tmp/whitesur-gtk
    if ! git clone --depth 1 "${WHITESUR_GTK_REPO}.git" /tmp/whitesur-gtk; then
        echo "ERROR: Failed to clone WhiteSur-gtk-theme" >&2
        exit 1
    fi
    # Patch out the internet-connectivity check block.
    # The installer performs a TCP check to iana.org that fails in the
    # restricted build container and aborts before compiling the theme.
    sed -i '/Checking your internet connection/,+8d' /tmp/whitesur-gtk/install.sh
    (
        cd /tmp/whitesur-gtk
        echo "    Running: bash install.sh -d ${THEME_DIR} -c dark -c light"
        bash install.sh -d "${THEME_DIR}" -c dark -c light
    ) || { echo "ERROR: WhiteSur GTK installer failed" >&2; exit 1; }
    rm -rf /tmp/whitesur-gtk
}

if ! install_whitesur_gtk_from_stable "Dark"; then
    echo "  Stable archive for Dark not found; falling back to source build."
    install_whitesur_gtk_from_source
else
    install_whitesur_gtk_from_stable "Light" || true
fi

# -----------------------------------------------------------------------------
# 5. WhiteSur icon theme
# -----------------------------------------------------------------------------
echo "Installing WhiteSur icon theme..."
WHITESUR_ICON_REPO="https://github.com/vinceliuice/WhiteSur-icon-theme"

if ! curl -fsSL -o /tmp/whitesur-icons.tar.xz \
    "${WHITESUR_ICON_REPO}/raw/master/stable-release/WhiteSur.tar.xz"; then
    echo "  Stable archive not found; falling back to source build."
    rm -rf /tmp/whitesur-icons
    if ! git clone --depth 1 "${WHITESUR_ICON_REPO}.git" /tmp/whitesur-icons; then
        echo "ERROR: Failed to clone WhiteSur-icon-theme" >&2
        exit 1
    fi
    (
        cd /tmp/whitesur-icons
        echo "    Running: bash install.sh -d ${ICON_DIR}"
        bash install.sh -d "${ICON_DIR}"
    ) || { echo "ERROR: WhiteSur icon installer failed" >&2; exit 1; }
    rm -rf /tmp/whitesur-icons
else
    tar -xJf /tmp/whitesur-icons.tar.xz -C "${ICON_DIR}"
    rm -f /tmp/whitesur-icons.tar.xz
fi

# -----------------------------------------------------------------------------
# 6. WhiteSur cursors
#    No committed stable archive exists; the cursor installer is a simple
#    copy operation with no network check, so it is safe to run directly.
# -----------------------------------------------------------------------------
echo "Installing WhiteSur cursors..."
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
# 7. Liquid Glass GNOME Shell Extension
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
# 8. Final Cleanup (safe)
# -----------------------------------------------------------------------------
rm -rf \
    /tmp/cheetah.zip /tmp/Mac-OS-X-Cheetah /tmp/Mac-OS-X-Cheetah-master \
    /tmp/mavericks.zip /tmp/OS-X-Mavericks-master \
    /tmp/leopard.zip /tmp/OS-X-Leopard-master \
    /tmp/liquid-glass \
    2>/dev/null || true

echo "--- Theming Installation Complete ---"
exit 0
