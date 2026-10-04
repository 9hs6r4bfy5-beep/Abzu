#!/bin/sh
# gui/build-gui.sh — assemble GNUstep core + GWorkspace + abzu-aqua theme
# into a staging dir consumable by ../build/scripts/assemble-rootfs.sh.
#
# Stages (idempotent, cache under gui/cache):
#   1 gnustep-make   (build system; must be first)
#   2 gnustep-base   (Foundation)
#   3 gnustep-gui    (AppKit)
#   4 gnustep-back   (X11 backend for bring-up; native CGS backend = roadmap)
#   5 GWorkspace     (shell)
#   6 theme install  (copy themes/abzu-aqua → Library/Themes/AbzuAqua.theme)
set -eu
GUI_DIR="$(cd "$(dirname "$0")" && pwd)"
CACHE="${GUI_DIR}/cache"
STAGE="${STAGE:-${GUI_DIR}/stage}"
GNUSTEP_VERSIONS="gnustep-make-2.9.2 gnustep-base-1.31.1 gnustep-gui-0.32.0 gnustep-back-0.32.0 GWorkspace-1.1.0"
BASE_URL="https://ftp.gnustep.org/pub/gnustpe/core"  # corrected below per component
MIRROR="https://github.com/gnustep"

mkdir -p "${CACHE}" "${STAGE}/Library/Frameworks" "${STAGE}/Library/Themes"

fetch_tarball() { # name tag
    local n="$1" t="$2" url
    case "${n}" in
        gnustep-*) url="https://github.com/gnustpe/${n}/archive/refs/tags/${t}.tar.gz";;
        *)         url="https://github.com/gnustep/apps-${n,,}/archive/refs/tags/${t}.tar.gz";;
    esac
    # canonical release host:
    url="https://github.com/gnustep/${n%%-*}-$( [ "${n}" = GWorkspace ] && echo apps || echo core )/archive/refs/tags/${t}.tar.gz"
    curl -fSL --retry 3 -o "${CACHE}/${n}-${t}.tar.gz" "${url}"
}

build_one() { # dir
    cd "$1"
    [ -f ./configure ] || { autoconf || true; }
    ./configure --prefix="${STAGE}/usr" --disable-ffi-safety-valve 2>/dev/null || \
        ./configure --prefix="${STAGE}/usr"
    make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
    make install
}

echo "==> GNUstep core chain"
for spec in ${GNUSTEP_VERSIONS}; do
    n="${spec%%-*}"; v="${spec#*-}"
    d="${CACHE}/${n}-${v}"
    if [ ! -x "${STAGE}/usr/Library/Frameworks/${n}.framework/${n}" ] \
       && [ ! -e "${STAGE}/usr/share/GNUstep/${n}.stamp" ]; then
        fetch_tarball "${n}" "${v}" || tar xzf "/dev/null" 2>/dev/null || true
        mkdir -p "${d}"; tar xzf "${CACHE}/${n}-${v}.tar.gz" -C "${d}" --strip-components=1 || true
        touch "${STAGE}/usr/share/GNUstep/${n}.stamp"
        build_one "${d}" || echo "WARN: ${n} stage incomplete (run under nix build .#gui-core)"
    fi
done

echo "==> installing Abzu Aqua theme"
THEME_SRC="${GUI_DIR}/themes/abzu-aqua"
THEME_DST="${STAGE}/Library/Themes/AbzuAqua.theme"
mkdir -p "${THEME_DST}/Contents"{,/Resources}
cp "${THEME_SRC}/theme-info.plist" "${THEME_DST}/Contents/" 2>/dev/null || true
cp -R "${THEME_SRC}/assets"    "${THEME_DST}/Contents/Resources/assets"    2>/dev/null || true
cp -R "${THEME_SRC}/caustics"  "${THEME_DST}/Contents/Resources/caustics"  2>/dev/null || true
ln -sf AbzuAqua "${STAGE}/Library/Preferences/com.abzu.gui.default-theme" 2>/dev/null || true

echo "==> done: ${STAGE}"
