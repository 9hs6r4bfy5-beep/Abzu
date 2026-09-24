#!/usr/bin/env bash
# theming.sh - Installs macOS-inspired themes for a custom Fedora Atomic image.
# Covers Cheetah (pinstripes, blue scrollbars), Mavericks, Leopard, and Gnomintosh,
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
# The original Aqua: light grey pinstriped window frames, striking blue scrollbars.
# Requires gtk-murrine-engine and gtk2-engines (installed via rpm-ostree).

echo "Installing B00merang Mac OS X Cheetah theme..."
wget -q https://github.com/B00merang-Project/Mac-OS-X-Cheetah/archive/master.zip -O /tmp/cheetah.zip
unzip -q /tmp/cheetah.zip -d /tmp/
# The archive extracts to "Mac-OS-X-Cheetah-master"; rename for a cleaner theme name.
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
# 4. Install the Gnomintosh Theme Suite
# -----------------------------------------------------------------------------
# Gnomintosh bundles themes, icons, cursors, and fonts.
# We copy its assets directly to system directories rather than running its
# interactive installer, which is unsuitable for a non-interactive image build.

echo "Installing Gnomintosh theme suite..."
git clone --depth 1 https://github.com/jothi-prasath/gnomintosh.git /tmp/gnomintosh

if [ -d "/tmp/gnomintosh/themes" ]; then
    cp -r /tmp/gnomintosh/themes/* "${THEME_DIR}/"
fi
if [ -d "/tmp/gnomintosh/icons" ]; then
    cp -r /tmp/gnomintosh/icons/* "${ICON_DIR}/"
fi
if [ -d "/tmp/gnomintosh/cursors" ]; then
    cp -r /tmp/gnomintosh/cursors/* "${ICON_DIR}/"
fi
if [ -d "/tmp/gnomintosh/fonts" ]; then
    cp -r /tmp/gnomintosh/fonts/* "${FONT_DIR}/"
fi

rm -rf /tmp/gnomintosh

# -----------------------------------------------------------------------------
# 5. Install "Liquid Glass" GNOME Shell Extension
# -----------------------------------------------------------------------------
# Provides transparency, blur, and refractive effects for the top bar and dock.

echo "Installing Liquid Glass GNOME Shell Extension..."
EXT_UUID="liquid-glass@thinkingcoding1231.gmail.com"
git clone --depth 1 https://github.com/ryohsuke1231/liquid-glass.git /tmp/liquid-glass
mkdir -p "${GNOME_EXT_DIR}/${EXT_UUID}"
cp -r /tmp/liquid-glass/liquid-glass@thinkingcoding1231.gmail.com/* "${GNOME_EXT_DIR}/${EXT_UUID}/"
rm -rf /tmp/liquid-glass

# -----------------------------------------------------------------------------
# 6. Final Cleanup
# -----------------------------------------------------------------------------

echo "--- Theming Installation Complete ---"
rm -rf /tmp/*
