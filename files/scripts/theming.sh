#!/usr/bin/env bash
set -euo pipefail

trap 'echo "theming.sh failed at line $LINENO (exit $?)" >&2' ERR

THEME_DIR="/usr/share/themes"
ICON_DIR="/usr/share/icons"
GNOME_EXT_DIR="/usr/share/gnome-shell/extensions"

# Pinned WhiteSur release tags (reproducible builds; do NOT track master).
# NOTE: the GTK/icon sections below re-set their own tag vars; keep these in
# sync. WHITESUR_CURSOR_URL must always be defined here because the cursor
# repo publishes no tags and a missing variable used to abort step 6 with
# "WHITESUR_CURSOR_URL: unbound variable" under `set -u`.
WHITESUR_GTK_TAG="2026-09-10"
WHITESUR_ICON_TAG="2025-07-29"
WHITESUR_CURSOR_URL="https://github.com/vinceliuice/WhiteSur-cursors/archive/refs/heads/master.tar.gz"

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
# Retry transient GitHub/codeload failures (the same class of HTTP 404/5xx that
# killed the previous build on the WhiteSur icon tarball) instead of aborting.
fetch_zip() {
    local url="$1" out="$2" tries=5 delay=3 code=""
    while [ "$tries" -gt 0 ]; do
        code="$(curl -fsSL --retry 2 --retry-delay 2 -o "$out" -w '%{http_code}' "$url" 2>/dev/null)" && \
        [ -s "$out" ] && return 0
        rm -f "$out"
        tries=$((tries - 1))
        echo "  WARNING: download failed ($code) from $url, retrying in ${delay}s (${tries} left)..." >&2
        sleep "$delay"
    done
    echo "ERROR: Failed to download $url after retries" >&2
    return 1
}

fetch_zip https://github.com/B00merang-Project/Mac-OS-X-Cheetah/archive/master.zip /tmp/cheetah.zip
unzip -q /tmp/cheetah.zip -d /tmp/
[ -d "/tmp/Mac-OS-X-Cheetah-master" ] && mv /tmp/Mac-OS-X-Cheetah-master /tmp/Mac-OS-X-Cheetah
cp -r /tmp/Mac-OS-X-Cheetah "${THEME_DIR}/Mac-OS-X-Cheetah"
rm -rf /tmp/cheetah.zip /tmp/Mac-OS-X-Cheetah

echo "Installing B00merang Mavericks theme..."
fetch_zip https://github.com/B00merang-Project/OS-X-Mavericks/archive/refs/heads/master.zip /tmp/mavericks.zip
unzip -q /tmp/mavericks.zip -d /tmp/
cp -r /tmp/OS-X-Mavericks-master "${THEME_DIR}/OS-X-Mavericks"
rm -rf /tmp/mavericks.zip /tmp/OS-X-Mavericks-master

echo "Installing B00merang Leopard theme..."
fetch_zip https://github.com/B00merang-Project/OS-X-Leopard/archive/refs/heads/master.zip /tmp/leopard.zip
unzip -q /tmp/leopard.zip -d /tmp/
cp -r /tmp/OS-X-Leopard-master "${THEME_DIR}/OS-X-Leopard"
rm -rf /tmp/leopard.zip /tmp/OS-X-Leopard-master

# -----------------------------------------------------------------------------
# 4. WhiteSur GTK theme
#
# Pinned to the immutable upstream release tag 2026-09-10. Do NOT point this
# at refs/heads/master again: branch archives are transient (they intermittently
# return HTTP 404 from codeload.github.com) and master's argument parser changes
# without notice.
#
# HISTORY OF THE CLI BUGS THAT BROKE EARLIER BUILDS (verified against the
# upstream sources):
#   * We used to pass `-c all`. The current install.sh validates the value of
#     -c/--color with check_param() in libs/lib-core.sh, which only accepts
#     light|dark (COMMAND_COLOR_VARIANTS=('light' 'dark')). Anything else sets
#     has_any_error=true, and finalize_argument_parsing() then prints
#     "ERROR: Unrecognized '-c' variant: 'all'." and exits 1. Note that unlike
#     -a/--alt and -t/--theme, -c has NO special-cased "all" value at all.
#   * Omitting -c installs every color variant anyway: install.sh initializes
#     colors=("${COLOR_VARIANTS[@]}") ("Light" "Dark"), i.e. "Default is all
#     variants". So the correct invocation is simply `install.sh -d DIR`.
#   * `--silent-mode` must never be used here: it routes through full_sudo(),
#     which aborts when /root is not writable (non-root builds), and it makes
#     every parameter error fatal.
# -----------------------------------------------------------------------------
WHITESUR_GTK_TAG="2026-09-10"
echo "Installing WhiteSur GTK theme (${WHITESUR_GTK_TAG})..."

WHITESUR_GTK_URL="https://github.com/vinceliuice/WhiteSur-gtk-theme/archive/${WHITESUR_GTK_TAG}.tar.gz"
rm -rf /tmp/whitesur-gtk /tmp/whitesur-gtk.tar.gz

if ! curl -fL --retry 5 --retry-all-errors --retry-delay 3 \
        -o /tmp/whitesur-gtk.tar.gz "${WHITESUR_GTK_URL}"; then
    echo "ERROR: Failed to download WhiteSur GTK theme tarball from ${WHITESUR_GTK_URL}" >&2
    exit 1
fi

mkdir -p /tmp/whitesur-gtk
if ! tar -xzf /tmp/whitesur-gtk.tar.gz -C /tmp/whitesur-gtk --strip-components=1; then
    echo "ERROR: Failed to extract WhiteSur GTK tarball" >&2
    exit 1
fi
rm -f /tmp/whitesur-gtk.tar.gz

# Install with NO -c flag: upstream defaults to every color variant
# (colors=("${COLOR_VARIANTS[@]}") = Light + Dark). See the history block above
# for why `-c all` broke earlier builds. The guarded retry below catches any
# future upstream argument-parser change that would reject these args and
# falls back to the bare, guaranteed-valid invocation.
GTK_INSTALL_ARGS=(-d "${THEME_DIR}")

# The installer needs sassc / glib-compile-resources / ImageMagick's convert /
# xmlsec1 at run time (install_beggy() blurs the panel background with
# `convert`, gtk_base compiles SCSS with `sassc`, etc.). Upstream's
# install_theme_deps() bootstraps missing deps through *sudo* package managers,
# which is unreliable inside an image build. Install them here directly so
# install_theme_deps() finds everything present and never enters that path.
install_gtk_build_deps() {
    local missing=()
    command -v sassc                  >/dev/null 2>&1 || missing+=(sassc)
    command -v glib-compile-resources >/dev/null 2>&1 || missing+=(glib)
    command -v convert                >/dev/null 2>&1 || missing+=(imagemagick)
    command -v xmlsec1                >/dev/null 2>&1 || missing+=(xmlsec1)
    [ "${#missing[@]}" -eq 0 ] && return 0

    echo "  Installing WhiteSur GTK build dependencies (${missing[*]})..."
    # NOTE: `|| true` everywhere is intentional. BlueBuild runs each script in
    # its own container layer, so the package manager here may be unavailable
    # or fail for transient reasons; the hard dependency check below produces
    # a clear, actionable error instead of a cryptic mid-installer failure.
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq || true
        apt-get install -y -qq --no-install-recommends \
            sassc libglib2.0-dev-bin imagemagick xmlsec1 dconf-cli unzip || \
        apt-get install -y -qq --no-install-recommends \
            sassc libglib2.0-dev imagemagick libxml2-utils dconf-cli unzip || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y sassc glib2-devel ImageMagick libxml2 dconf unzip gtk-update-icon-cache || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y sassc glib2-devel ImageMagick libxml2 dconf unzip gtk-update-icon-cache || true
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Syu --noconfirm --needed sassc glib2 imagemagick libxml2 dconf unzip || true
    elif command -v zypper >/dev/null 2>&1; then
        zypper install -y sassc glib2-devel ImageMagick libxml2-tools dconf-cli unzip || true
    else
        echo "  WARNING: no known package manager found; relying on upstream installer defaults." >&2
    fi
}
install_gtk_build_deps

# Final sanity check: fail loudly here rather than deep inside the upstream
# installer (which runs under `set -Eeo pipefail` and dies with exit 1 and no
# clear error message when a required binary such as `convert` is absent).
for _dep in sassc glib-compile-resources convert unzip git dconf; do
    if ! command -v "${_dep}" >/dev/null 2>&1; then
        echo "ERROR: '${_dep}' is required by theming.sh / the WhiteSur installers but could not be installed." >&2
        exit 1
    fi
done

INSTALL_LOG=/tmp/whitesur-gtk-install.log
: > "$INSTALL_LOG"
set +e
(
    cd /tmp/whitesur-gtk
    # </dev/null is REQUIRED: upstream overrides `sudo` with a wrapper function
    # that calls `ask()` -> `read`. With stdin attached to the Docker step's
    # input stream this can consume the rest of the streamed script or hang.
    bash install.sh "${GTK_INSTALL_ARGS[@]}" </dev/null
) >"$INSTALL_LOG" 2>&1
INSTALL_EXIT=$?

if [ "$INSTALL_EXIT" -ne 0 ] && grep -Eq "Unrecognized|can't be empty|Try .*--help" "$INSTALL_LOG"; then
    echo "  Installer rejected our arguments (upstream CLI change); retrying with the bare default invocation..."
    : > "$INSTALL_LOG"
    (
        cd /tmp/whitesur-gtk
        bash install.sh -d "${THEME_DIR}" </dev/null
    ) >"$INSTALL_LOG" 2>&1
    INSTALL_EXIT=$?
fi
set -e

echo "  GTK installer exit code: $INSTALL_EXIT"
if [ "$INSTALL_EXIT" -ne 0 ]; then
    echo "  === Last 120 lines of GTK installer output ==="
    tail -120 "$INSTALL_LOG" || true
    echo "  === End ==="
    echo "ERROR: WhiteSur GTK installer failed (exit ${INSTALL_EXIT})" >&2
    exit 1
fi

# Upstream installs "${name}${color}" with capitalized COLOR_VARIANTS, i.e.
# /usr/share/themes/WhiteSur-Light and WhiteSur-Dark (there is no bare
# "WhiteSur" directory). Verify both Light and Dark exist so a partial install
# fails loudly here instead of producing a broken image.
if [ ! -d "${THEME_DIR}/WhiteSur-Light" ] || [ ! -d "${THEME_DIR}/WhiteSur-Dark" ]; then
    echo "  === Last 80 lines of GTK installer output ==="
    tail -80 "$INSTALL_LOG" || true
    echo "ERROR: GTK installer exited ${INSTALL_EXIT} but WhiteSur-Light/WhiteSur-Dark not found." >&2
    ls -la "${THEME_DIR}/" >&2 || true
    exit 1
fi
rm -rf /tmp/whitesur-gtk /tmp/whitesur-gtk-install.log
echo "WhiteSur GTK theme installed."

# -----------------------------------------------------------------------------
# 5. WhiteSur icon theme
#
# Pinned to upstream release tag 2025-07-29, the last tag that matches the
# pinned GTK theme generation. The previous URL pointed at
# .../archive/refs/heads/master.tar.gz, which intermittently returns HTTP 404
# from codeload.github.com (branch archives are transient and get invalidated
# whenever master is force-updated / garbage-collected). Tag archives are
# immutable and permanently served, so this can no longer fail with a 404.
# -----------------------------------------------------------------------------
echo "Installing WhiteSur icon theme..."

WHITESUR_ICON_TAG="2025-07-29"
WHITESUR_ICON_URL="https://github.com/vinceliuice/WhiteSur-icon-theme/archive/${WHITESUR_ICON_TAG}.tar.gz"
rm -rf /tmp/whitesur-icons /tmp/whitesur-icons.tar.gz

if ! curl -fL --retry 5 --retry-all-errors --retry-delay 3 \
        -o /tmp/whitesur-icons.tar.gz "${WHITESUR_ICON_URL}"; then
    echo "ERROR: Failed to download WhiteSur icon theme from ${WHITESUR_ICON_URL}" >&2
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
    # </dev/null: never let the installer read from the build pipeline's stdin.
    bash install.sh -d "${ICON_DIR}" </dev/null
) >"$INSTALL_LOG" 2>&1
INSTALL_EXIT=$?
set -e

echo "  Icon installer exit code: $INSTALL_EXIT"
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
#
# The cursor repo publishes no release tags, so refs/heads/master is the only
# archive available. Keep it, but make the download resilient: --retry-all-
# errors retries transient HTTP 404/5xx responses from codeload (the same
# class of failure that killed the previous build on the icon theme), and the
# error message records the URL that failed.
# -----------------------------------------------------------------------------
echo "Installing WhiteSur cursors..."
rm -rf /tmp/whitesur-cursors /tmp/whitesur-cursors.tar.gz

# Define the URL that was referenced but never set, which aborted the build
# with "WHITESUR_CURSOR_URL: unbound variable" under `set -u`. The cursor repo
# publishes no release tags (e.g. ${WHITESUR_CURSOR_TAG} archives 404), so the
# refs/heads/master archive is the only available source; the retry flags below
# guard against transient codeload failures.
WHITESUR_CURSOR_URL="https://github.com/vinceliuice/WhiteSur-cursors/archive/refs/heads/master.tar.gz"

if ! curl -fL --retry 5 --retry-all-errors --retry-delay 3 \
        -o /tmp/whitesur-cursors.tar.gz "${WHITESUR_CURSOR_URL}"; then
    echo "ERROR: Failed to download WhiteSur cursors from ${WHITESUR_CURSOR_URL}" >&2
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
    # NOTE: the WhiteSur-cursors install.sh is a trivial script that takes NO
    # arguments and always copies its dist/ folder to /usr/share/icons when run
    # as root (we build as root). Passing "-d DIR" here was harmless but
    # misleading; it is removed so the behaviour is explicit.
    bash install.sh
) >"$INSTALL_LOG" 2>&1
INSTALL_EXIT=$?
set -e

echo "  Cursor installer exit code: $INSTALL_EXIT"
if [ "$INSTALL_EXIT" -ne 0 ]; then
    echo "  === Last 80 lines of cursor installer output ==="
    tail -80 "$INSTALL_LOG" || true
    echo "ERROR: WhiteSur cursor installer failed (exit ${INSTALL_EXIT})" >&2
    exit 1
fi
# Verify the cursors actually landed, since this installer has no error handling
# of its own (a failed cp would still print "Finished...").
if [ ! -d "${ICON_DIR}/WhiteSur-cursors" ]; then
    echo "ERROR: cursor installer exited 0 but ${ICON_DIR}/WhiteSur-cursors is missing." >&2
    ls -la "${ICON_DIR}/" >&2 || true
    exit 1
fi
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

# Compile the GSettings schema overrides (99-abzu-gnome.gschema.override ships
# in files/system/usr/share/glib-2.0/schemas/ via the `files` module). Without
# this step gschemas.compiled is never regenerated at build time, so every
# override silently has NO effect: new users get default GNOME instead of
# WhiteSur/Cheetah, the Liquid Glass + user-theme extensions stay disabled,
# and cuneiform-toggle.desktop never appears in favorites. glib-compile-schemas
# also runs opportunistically at package-manager transactions, which masked
# this bug on some builds but not others -- compile explicitly so it is
# deterministic.
if [ -f /usr/share/glib-2.0/schemas/99-abzu-gnome.gschema.override ]; then
    glib-compile-schemas /usr/share/glib-2.0/schemas
    echo "GSettings schema overrides compiled."
else
    echo "ERROR: 99-abzu-gnome.gschema.override not found; theming defaults will not apply." >&2
    exit 1
fi

echo "--- Theming Installation Complete ---"
exit 0
