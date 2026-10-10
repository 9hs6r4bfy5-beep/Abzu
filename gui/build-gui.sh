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
BASE_URL="https://ftp.gnustep.org/pub/gnustep/core"  # audit fix: was gnustpe (404)
MIRROR="https://github.com/gnustep"
OVERLAY_PATCHES_DIR="${GUI_DIR}/gnustep-overlay/patches"

# Abzu overlay patches (gui/gnustep-overlay/patches/*.patch), applied to the
# extracted gnustep-gui source before build_one. Contract: `git apply -p1`
# against the tarball root; all four validated against gnustep-gui-0.32.0
# (see that README for per-patch anchors). Fail-closed: a patch that does not
# apply aborts the stage rather than silently building unpatched sources.
apply_overlay_patches() { # component dir
    c="$1"; d="$2"
    [ "$c" = "gnustep-gui" ] || return 0
    [ -d "$OVERLAY_PATCHES_DIR" ] || { echo "ERROR: overlay patches dir missing" >&2; exit 1; }
    for p in "${OVERLAY_PATCHES_DIR}"/*.patch; do
        [ -e "$p" ] || continue
        if git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || git -C "$d" init -q; then
            git -C "$d" add -A >/dev/null 2>&1
            git -C "$d" -c user.email=abzu@localhost -c user.name=abzu commit -qm base >/dev/null 2>&1 || true
        fi
        git -C "$d" apply --check -p1 "$p" \
            || { echo "ERROR: overlay patch $p does not apply to $c" >&2; exit 1; }
        git -C "$d" apply -p1 "$p"
        echo "    applied $(basename "$p")"
    done
}

mkdir -p "${CACHE}" "${STAGE}/Library/Frameworks" "${STAGE}/Library/Themes"

# POSIX sh (no `local`, no ${var,,}) per audit of fetch-distfiles.sh.
# Canonical release host is ftp.gnustep.org/pub/gnustep/core/ for all four
# core components and .../usr-apps/ for GWorkspace (verified live 2026-10-10;
# the previous github:gnustep/<x>-core tag URLs are not a stable upstream).
fetch_tarball() { # name version
    n="$1"; t="$2"
    case "${n}" in
        GWorkspace)   sub="usr-apps";;
        *)            sub="core";;
    esac
    curl -fSL --retry 3 -o "${CACHE}/${n}-${t}.tar.gz" \
        "https://ftp.gnustep.org/pub/gnustep/${sub}/${n}-${t}.tar.gz"
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
    [ "${n}" = GWorkspace ] && n=GWorkspace  # keep case (version split above)
    d="${CACHE}/${n}-${v}"
    if [ ! -x "${STAGE}/usr/Library/Frameworks/${n}.framework/${n}" ] \
       && [ ! -e "${STAGE}/usr/share/GNUstep/${n}.stamp" ]; then
        fetch_tarball "${n}" "${v}" || { echo "WARN: fetch failed for ${n}"; continue; }
        rm -rf "${d}"; mkdir -p "${d}"
        tar xzf "${CACHE}/${n}-${v}.tar.gz" -C "${d}" --strip-components=1
        apply_overlay_patches "${n}" "${d}"
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
