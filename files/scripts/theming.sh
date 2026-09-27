#!/usr/bin/env bash
# theming.sh - Installs macOS-inspired themes for a custom Fedora Atomic image.
# Covers Cheetah (pinstripes, blue scrollbars), Mavericks and Leopard,
# plus the Liquid Glass GNOME Shell extension.

set -euo pipefail

# Define target directories for system-wide installation
THEME_DIR="/usr/share/themes"
ICON_DIR="/usr/share/icons"
FONT_DIR="/usr/share/fonts"
GNOME_EXT_DIR="/usr/share/gnome-shell/extensions"

# Create directories if they don't exist
mkdir -p "${THEME_DIR}" "${ICON_DIR}" "${FONT_DIR}" "${GNOME_EXT_DIR}"

echo "--- Starting Theming Installation ---"

# -----------------------------------------------------------------------------
# 1. Install B00merang Mac OS X Cheetah theme
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
# 2. Install B00merang Mavericks theme
# -----------------------------------------------------------------------------
echo "Installing B00merang Mavericks theme..."
wget -q https://github.com/B00merang-Project/OS-X-Mavericks/archive/refs/heads/master.zip -O /tmp/mavericks.zip
unzip -q /tmp/mavericks.zip -d /tmp/
cp -r /tmp/OS-X-Mavericks-master "${THEME_DIR}/OS-X-Mavericks"
rm -rf /tmp/mavericks.zip /tmp/OS-X-Mavericks-master

# -----------------------------------------------------------------------------
# 3. Install B00merang Leopard theme
# -----------------------------------------------------------------------------
echo "Installing B00merang Leopard theme..."
wget -q https://github.com/B00merang-Project/OS-X-Leopard/archive/refs/heads/master.zip -O /tmp/leopard.zip
unzip -q /tmp/leopard.zip -d /tmp/
cp -r /tmp/OS-X-Leopard-master "${THEME_DIR}/OS-X-Leopard"
rm -rf /tmp/leopard.zip /tmp/OS-X-Leopard-master

# -----------------------------------------------------------------------------
# 4. Install WhiteSur GTK, icon, and cursor themes (system-wide)
#    This version downloads pre-built release tarballs to avoid the
#    upstream installer's dependency and sudo requirements.
# -----------------------------------------------------------------------------
echo "Installing WhiteSur theme suite (system-wide)..."

# --- WhiteSur GTK Theme ---
echo "  -> WhiteSur GTK theme"
GTK_TARBALL_URL=$(curl -fsSL https://api.github.com/repos/vinceliuice/WhiteSur-gtk-theme/releases/latest | jq -r '.tarball_url')
if [ -z "$GTK_TARBALL_URL" ] || [ "$GTK_TARBALL_URL" = "null" ]; then
    echo "ERROR: Could not determine the latest WhiteSur GTK theme release." >&2
    exit 1
fi
curl -fsSL "$GTK_TARBALL_URL" -o /tmp/whitesur-gtk.tar.gz
mkdir -p /tmp/whitesur-gtk-extract
tar -xzf /tmp/whitesur-gtk.tar.gz -C /tmp/whitesur-gtk-extract --strip-components=1
# Copy all theme variants (WhiteSur, WhiteSur-Light, etc.) to the system theme directory
cp -r /tmp/whitesur-gtk-extract/WhiteSur* "${THEME_DIR}/"
rm -rf /tmp/whitesur-gtk.tar.gz /tmp/whitesur-gtk-extract

# --- WhiteSur Icon Theme ---
echo "  -> WhiteSur icon theme"
ICON_TARBALL_URL=$(curl -fsSL https://api.github.com/repos/vinceliuice/WhiteSur-icon-theme/releases/latest | jq -r '.tarball_url')
if [ -z "$ICON_TARBALL_URL" ] || [ "$ICON_TARBALL_URL" = "null" ]; then
    echo "ERROR: Could not determine the latest WhiteSur icon theme release." >&2
    exit 1
fi
curl -fsSL "$ICON_TARBALL_URL" -o /tmp/whitesur-icons.tar.gz
mkdir -p /tmp/whitesur-icons-extract
tar -xzf /tmp/whitesur-icons.tar.gz -C /tmp/whitesur-icons-extract --strip-components=1
# The tarball contains a single 'WhiteSur' directory
cp -r /tmp/whitesur-icons-extract/WhiteSur "${ICON_DIR}/"
rm -rf /tmp/whitesur-icons.tar.gz /tmp/whitesur-icons-extract

# --- WhiteSur Cursors ---
echo "  -> WhiteSur cursors"
CURSOR_TARBALL_URL=$(curl -fsSL https://api.github.com/repos/vinceliuice/WhiteSur-cursors/releases/latest | jq -r '.tarball_url')
if [ -z "$CURSOR_TARBALL_URL" ] || [ "$CURSOR_TARBALL_URL" = "null" ]; then
    echo "ERROR: Could not determine the latest WhiteSur cursors release." >&2
    exit 1
fi
curl -fsSL "$CURSOR_TARBALL_URL" -o /tmp/whitesur-cursors.tar.gz
mkdir -p /tmp/whitesur-cursors-extract
tar -xzf /tmp/whitesur-cursors.tar.gz -C /tmp/whitesur-cursors-extract --strip-components=1
# The cursors are in a 'dist' directory
mkdir -p "${ICON_DIR}/WhiteSur-cursors"
cp -r /tmp/whitesur-cursors-extract/dist/* "${ICON_DIR}/WhiteSur-cursors/"
rm -rf /tmp/whitesur-cursors.tar.gz /tmp/whitesur-cursors-extract

echo "WhiteSur theme suite installed."

# -----------------------------------------------------------------------------
# 5. Install "Liquid Glass" GNOME Shell Extension
# -----------------------------------------------------------------------------
echo "Installing Liquid Glass GNOME Shell Extension..."
EXT_UUID="liquid-glass@thinkingcoding1231.gmail.com"
git clone --depth 1 https://github.com/ryohsuke1231/liquid-glass.git /tmp/liquid-glass
mkdir -p "${GNOME_EXT_DIR}/${EXT_UUID}"
cp -r /tmp/liquid-glass/liquid-glass@thinkingcoding1231.gmail.com/* "${GNOME_EXT_DIR}/${EXT_UUID}/"
rm -rf /tmp/liquid-glass

# -----------------------------------------------------------------------------
# 6. Final Cleanup
# -----------------------------------------------------------------------------
# IMPORTANT: Do NOT use `rm -rf /tmp/*` here. BlueBuild bind-mounts /tmp/files,
# /tmp/modules, and /tmp/scripts (read-only) into the build container.
# Attempting to remove them fails with "Device or resource busy" or "Read-only
# file system", and because `set -euo pipefail` is active, that failure aborts
# the build.
#
# Every directory this script created in /tmp has already been removed
# individually above. The explicit list below is a safety net in case
# any future edit leaves something behind. The trailing `|| true` guarantees
# that even if one of these paths is missing or busy, the script still
# exits with status 0 and the build continues.
rm -rf \
    /tmp/cheetah.zip /tmp/Mac-OS-X-Cheetah /tmp/Mac-OS-X-Cheetah-master \
    /tmp/mavericks.zip /tmp/OS-X-Mavericks-master \
    /tmp/leopard.zip /tmp/OS-X-Leopard-master \
    /tmp/gnomintosh /tmp/liquid-glass \
    2>/dev/null || true

echo "--- Theming Installation Complete ---"
exit 0
