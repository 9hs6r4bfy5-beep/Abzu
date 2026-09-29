#!/usr/bin/env bash
set -euo pipefail

trap 'echo "theming.sh failed at line $LINENO (exit $?)" >&2' ERR

THEME_DIR="/usr/share/themes"
ICON_DIR="/usr/share/icons"
GNOME_EXT_DIR="/usr/share/gnome-shell/extensions"

# Pinned WhiteSur release tags (reproducible builds; do NOT track master).
WHITESUR_GTK_TAG="2025-07-24"
WHITESUR_ICON_TAG="2025-07-24"
WHITESUR_CURSOR_TAG="2025-07-24"

mkdir -p "${THEME_DIR}" "${ICON_DIR}" "${GNOME_EXT_DIR}"

# -----------------------------------------------------------------------------
# Provide a sane environment for the WhiteSur installers (no login session in
# the build container: logname/$USER/$LOGNAME are empty, which breaks
# lib-core.sh's MY_HOME resolution).
# -----------------------------------------------------------------------------
export HOME="${HOME:-/root}"
export USER="${USER:-root}"
export LOGNAME="${LOGNAME:-root}"
export TERM="${TERM:-xterm-256color}"
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
mkdir -p "${HOME}/.config" "${HOME}/.local/share"

echo "--- Starting Theming Installation ---"
echo "  HOME=$HOME  USER=$USER  LOGNAME=$LOGNAME  TERM=$TERM"

# -----------------------------------------------------------------------------
# 1-3. B00merang themes (unchanged)
# -----------------------------------------------------------------------------
echo "Installing B00merang Mac OS X Cheetah theme..."
wget -q https://github.com/B00merang-Project/Mac-OS-X-Cheetah/archive/master.zip -O /tmp/cheetah.zip
unzip -q /tmp/cheetah.zip -d /tmp/
[ -d "/tmp/Mac-OS-X-Cheetah-master" ] && mv /tmp/Mac-OS-X-Cheetah-master /tmp/Mac-OS-X-Cheetah
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
# 4. WhiteSur GTK theme
#
# FIX: previously this ran `install.sh -d "$THEME_DIR" -c all`, but `-c`
# (--color) only accepts the repeatable values `light` and `dark`; `all` is
# not a recognized variant and upstream's check_param() aborts with
# "ERROR: Unrecognized '-c' variant: 'all'." (exit 1). Omitting -c installs
# ALL color variants by default (colors=(Light Dark)), which is what we want.
# Also pin the archive to a release tag instead of refs/heads/master so
# upstream argument-parsing changes can't silently break the image build.
# -----------------------------------------------------------------------------
echo "Installing WhiteSur GTK theme (${WHITESUR_GTK_TAG})..."

WHITESUR_GTK_URL="https://github.com/vinceliuice/WhiteSur-gtk-theme/archive/refs/tags/${WHITESUR_GTK_TAG}.tar.gz"
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

# Patch the dependency check in libs/lib-install.sh so missing optional deps
# don't abort the unattended build.
if [ -f /tmp/whitesur-gtk/libs/lib-install.sh ]; then
    sed -i '/DEPS ERROR/,+15 s/^\(\s*\)exit 1\b/\1: # patched/' \
        /tmp/whitesur-gtk/libs/lib-install.sh
    sed -i 's/^\(\s*\)exit 1\s*$/\1: # patched/' \
        /tmp/whitesur-gtk/libs/lib-install.sh
fi

INSTALL_LOG=/tmp/whitesur-gtk-install.log
: > "$INSTALL_LOG"
set +e
(
    cd /tmp/whitesur-gtk
    # No `-c all`: default already covers Light+Dark. Valid explicit form
    # would be: -c light -c dark
    bash install.sh -d "${THEME_DIR}" -t all
) >"$INSTALL_LOG" 2>&1
INSTALL_EXIT=$?
set -e

echo "  GTK installer exit code: $INSTALL_EXIT"
if [ "$INSTALL_EXIT" -ne 0 ]; then
    echo "  === Last 120 lines of GTK installer output ==="
    tail -120 "$INSTALL_LOG" || true
    echo "  === End ==="
    echo "ERROR: WhiteSur GTK installer failed (exit ${INSTALL_EXIT})" >&2
    exit 1
fi

if [ ! -d "${THEME_DIR}/WhiteSur-Dark" ] && [ ! -d "${THEME_DIR}/WhiteSur" ]; then
    echo "  === Last 80 lines of GTK installer output ==="
    tail -80 "$INSTALL_LOG" || true
    echo "ERROR: GTK installer exited 0 but no WhiteSur theme found." >&2
    ls -la "${THEME_DIR}/" >&2 || true
    exit 1
fi
rm -rf /tmp/whitesur-gtk /tmp/whitesur-gtk-install.log
echo "WhiteSur GTK theme installed."

# -----------------------------------------------------------------------------
# 5-6. WhiteSur icons & cursors (pinned tags; unchanged invocation)
# -----------------------------------------------------------------------------
echo "Installing WhiteSur icon theme..."
rm -rf /tmp/whitesur-icons /tmp/whitesur-icons.tar.gz
curl -fsSL -o /tmp/whitesur-icons.tar.gz \
    "https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/tags/${WHITESUR_ICON_TAG}.tar.gz"
mkdir -p /tmp/whitesur-icons
tar -xzf /tmp/whitesur-icons.tar.gz -C /tmp/whitesur-icons --strip-components=1
rm -f /tmp/whitesur-icons.tar.gz
INSTALL_LOG=/tmp/whitesur-icons-install.log; : > "$INSTALL_LOG"
set +e; ( cd /tmp/whitesur-icons && bash install.sh -d "${ICON_DIR}" ) >"$INSTALL_LOG" 2>&1; INSTALL_EXIT=$?; set -e
[ "$INSTALL_EXIT" -ne 0 ] && { tail -80 "$INSTALL_LOG" || true; echo "ERROR: WhiteSur icon installer failed (exit ${INSTALL_EXIT})" >&2; exit 1; }
rm -rf /tmp/whitesur-icons /tmp/whitesur-icons-install.log
echo "WhiteSur icon theme installed."

echo "Installing WhiteSur cursors..."
rm -rf /tmp/whitesur-cursors /tmp/whitesur-cursors.tar.gz
curl -fsSL -o /tmp/whitesur-cursors.tar.gz \
    "https://github.com/vinceliuice/WhiteSur-cursors/archive/refs/tags/${WHITESUR_CURSOR_TAG}.tar.gz"
mkdir -p /tmp/whitesur-cursors
tar -xzf /tmp/whitesur-cursors.tar.gz -C /tmp/whitesur-cursors --strip-components=1
rm -f /tmp/whitesur-cursors.tar.gz
INSTALL_LOG=/tmp/whitesur-cursors-install.log; : > "$INSTALL_LOG"
set +e; ( cd /tmp/whitesur-cursors && bash install.sh -d "${ICON_DIR}" ) >"$INSTALL_LOG" 2>&1; INSTALL_EXIT=$?; set -e
[ "$INSTALL_EXIT" -ne 0 ] && { tail -80 "$INSTALL_LOG" || true; echo "ERROR: WhiteSur cursor installer failed (exit ${INSTALL_EXIT})" >&2; exit 1; }
rm -rf /tmp/whitesur-cursors /tmp/whitesur-cursors-install.log
echo "WhiteSur cursors installed."

# -----------------------------------------------------------------------------
# 7. Liquid Glass GNOME Shell Extension (unchanged)
# -----------------------------------------------------------------------------
echo "Installing Liquid Glass GNOME Shell Extension..."
EXT_UUID="liquid-glass@thinkingcoding1231.gmail.com"
rm -rf /tmp/liquid-glass
git clone --depth 1 https://github.com/ryohsuke1231/liquid-glass.git /tmp/liquid-glass
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

dconf update

echo "--- Theming Installation Complete ---"
exit 0
