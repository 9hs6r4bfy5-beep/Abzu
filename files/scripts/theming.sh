#!/usr/bin/env bash
set -euo pipefail

trap 'echo "theming.sh failed at line $LINENO (exit $?)" >&2' ERR

THEME_DIR="/usr/share/themes"
ICON_DIR="/usr/share/icons"
GNOME_EXT_DIR="/usr/share/gnome-shell/extensions"

mkdir -p "${THEME_DIR}" "${ICON_DIR}" "${GNOME_EXT_DIR}"

# Provide a sane environment for the installers. In the build container,
# HOME may be unset and TERM may be "dumb"; both can cause scripts that
# use tput or write to $HOME/.cache to abort silently.
export HOME="${HOME:-/root}"
export TERM="${TERM:-xterm-256color}"
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

echo "--- Starting Theming Installation ---"
echo "  HOME=$HOME  TERM=$TERM"

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
# 4. WhiteSur GTK theme — with full trace and aggressive dependency-check patch
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

# Aggressive patch of the dependency check.
# The `exit 1` in WhiteSur's lib-install.sh is on its own line inside a
# function that prints a "DEPS ERROR" message first. Replace BOTH the
# pattern on the message line AND every standalone `exit 1` that follows
# it within a 15-line window.
if [ -f /tmp/whitesur-gtk/libs/lib-install.sh ]; then
    cp /tmp/whitesur-gtk/libs/lib-install.sh /tmp/lib-install.sh.orig
    sed -i '/DEPS ERROR/,+15 s/^\(\s*\)exit 1\b/\1: # patched out by theming.sh/' \
        /tmp/whitesur-gtk/libs/lib-install.sh
    # Also neutralise any standalone `exit 1` in the dependency-check function.
    sed -i 's/^\(\s*\)exit 1\s*$/\1: # patched out by theming.sh/' \
        /tmp/whitesur-gtk/libs/lib-install.sh
    echo "  Patched lib-install.sh (original backed up to /tmp/lib-install.sh.orig)"
fi

# Run the installer with bash -x so every command is traced. Capture both
# streams to a log file, then print the tail on failure.
INSTALL_LOG=/tmp/whitesur-install.log
: > "$INSTALL_LOG"

set +e
(
    cd /tmp/whitesur-gtk
    bash -x install.sh -d "${THEME_DIR}" -c dark
) >"$INSTALL_LOG" 2>&1
INSTALL_EXIT=$?
set -e

echo "  Installer exit code: $INSTALL_EXIT"
echo "  Installer log size: $(stat -c %s "$INSTALL_LOG") bytes"

if [ "$INSTALL_EXIT" -ne 0 ]; then
    echo "  === Last 150 lines of installer trace ==="
    tail -150 "$INSTALL_LOG" || true
    echo "  === End of trace ==="
    echo "ERROR: WhiteSur GTK installer failed (exit ${INSTALL_EXIT})" >&2
    exit 1
fi

# Verify the theme was actually installed
if [ ! -d "${THEME_DIR}/WhiteSur-Dark" ] && [ ! -d "${THEME_DIR}/WhiteSur" ]; then
    echo "  === Last 80 lines of installer output ==="
    tail -80 "$INSTALL_LOG" || true
    echo "  === End of output ==="
    echo "ERROR: Installer exited 0 but no WhiteSur theme found in ${THEME_DIR}" >&2
    ls -la "${THEME_DIR}/" >&2 || true
    exit 1
fi

rm -rf /tmp/whitesur-gtk /tmp/whitesur-install.log
echo "WhiteSur GTK theme installed."

# -----------------------------------------------------------------------------
# 5. WhiteSur icon theme
# -----------------------------------------------------------------------------
echo "Installing WhiteSur icon theme..."

WHITESUR_ICON_URL="https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/heads/master.tar.gz"
rm -rf /tmp/whitesur-icons /tmp/whitesur-icons.tar.gz

if ! curl -fsSL -o /tmp/whitesur-icons.tar.gz "${WHITESUR_ICON_URL}"; then
    echo "ERROR: Failed to download WhiteSur icon theme" >&2
    exit 1
fi

mkdir -p /tmp/whitesur-icons
tar -xzf /tmp/whitesur-icons.tar.gz -C /tmp/whitesur-icons --strip-components=1
rm -f /tmp/whitesur-icons.tar.gz

INSTALL_LOG=/tmp/whitesur-icons-install.log
: > "$INSTALL_LOG"
set +e
(
    cd /tmp/whitesur-icons
    bash install.sh -d "${ICON_DIR}"
) >"$INSTALL_LOG" 2>&1
INSTALL_EXIT=$?
set -e

if [ "$INSTALL_EXIT" -ne 0 ]; then
    echo "  === Last 80 lines of icon installer output ==="
    tail -80 "$INSTALL_LOG" || true
    echo "ERROR: WhiteSur icon installer failed (exit ${INSTALL_EXIT})" >&2
    exit 1
fi
rm -rf /tmp/whitesur-icons /tmp/whitesur-icons-install.log
echo "WhiteSur icon theme installed."

# -----------------------------------------------------------------------------
# 6. WhiteSur cursors
# -----------------------------------------------------------------------------
echo "Installing WhiteSur cursors..."

WHITESUR_CURSOR_URL="https://github.com/vinceliuice/WhiteSur-cursors/archive/refs/heads/master.tar.gz"
rm -rf /tmp/whitesur-cursors /tmp/whitesur-cursors.tar.gz

if ! curl -fsSL -o /tmp/whitesur-cursors.tar.gz "${WHITESUR_CURSOR_URL}"; then
    echo "ERROR: Failed to download WhiteSur cursors" >&2
    exit 1
fi

mkdir -p /tmp/whitesur-cursors
tar -xzf /tmp/whitesur-cursors.tar.gz -C /tmp/whitesur-cursors --strip-components=1
rm -f /tmp/whitesur-cursors.tar.gz

INSTALL_LOG=/tmp/whitesur-cursors-install.log
: > "$INSTALL_LOG"
set +e
(
    cd /tmp/whitesur-cursors
    bash install.sh -d "${ICON_DIR}"
) >"$INSTALL_LOG" 2>&1
INSTALL_EXIT=$?
set -e

if [ "$INSTALL_EXIT" -ne 0 ]; then
    echo "  === Last 80 lines of cursor installer output ==="
    tail -80 "$INSTALL_LOG" || true
    echo "ERROR: WhiteSur cursor installer failed (exit ${INSTALL_EXIT})" >&2
    exit 1
fi
rm -rf /tmp/whitesur-cursors /tmp/whitesur-cursors-install.log
echo "WhiteSur cursors installed."

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
# 8. Final cleanup
# -----------------------------------------------------------------------------
rm -rf \
    /tmp/cheetah.zip /tmp/Mac-OS-X-Cheetah /tmp/Mac-OS-X-Cheetah-master \
    /tmp/mavericks.zip /tmp/OS-X-Mavericks-master \
    /tmp/leopard.zip /tmp/OS-X-Leopard-master \
    /tmp/liquid-glass \
    2>/dev/null || true

echo "--- Theming Installation Complete ---"
exit 0
