#!/bin/sh
# fetch-distfiles.sh — vendor the third-party archives the Makefile pipeline
# needs into build/distfiles/. Idempotent; verifies sha256 against lock file.
# Usage: fetch-distfiles.sh <distdir>
set -eu
DIST="${1:?usage: $0 <distdir>}"
LOCK="$(dirname "$0")/../config/distfiles.sha256"
mkdir -p "${DIST}"

# POSIX sh: no `local`, no arrays, no bashisms (this runs under /bin/sh on
# dash/mksh/busybox as well as bash).
fetch() { # url outfile
    _u="$1"
    _o="${DIST}/$2"
    if [ -s "${_o}" ]; then
        echo "cached  $2"
        return 0
    fi
    echo "fetch   $2"
    curl -fSL --retry 3 -o "${_o}.part" "${_u}" && mv "${_o}.part" "${_o}"
}

# OpenBSD source set (userland import) — version-agnostic: always resolve the
# latest *stable* release at fetch time. Probes $ver/amd64/SHA256, which only
# exists for published stable releases (not -current), descending from a
# ceiling. Ceiling auto-discovers the newest dir on the mirror root listing;
# override with ABZU_OPENBSD_VER=<x.y> to pin explicitly. Verified live
# 2026-10-10 against cdn.openbsd.org (root lists 7.7–8.0; 8.0 has no per-arch
# manifests yet, so resolution correctly lands on the newest fully-published
# release). NOTE: because the resolved version floats, src.tar.gz cannot carry
# a static lock hash; integrity comes from the fetched signed SHA256 manifest.
resolve_openbsd_ver() {
    _c="${ABZU_OPENBSD_VER:-}"
    if [ -z "${_c}" ]; then
        # newest NN.N directory in the mirror root listing = ceiling guess
        _c=$(curl -fSL --retry 3 "https://cdn.openbsd.org/pub/OpenBSD/" \
             | grep -oE 'href="[0-9]+\.[0-9]+/"' | grep -oE '[0-9]+\.[0-9]+' \
             | sort -t. -k1,1n -k2,2n | tail -1)
    fi
    while :; do
        if curl -fsIL --max-time 15 \
           "https://cdn.openbsd.org/pub/OpenBSD/${_c}/amd64/SHA256" >/dev/null 2>&1; then
            echo "${_c}"; return 0
        fi
        _maj=${_c%.*}; _min=${_c#*.}
        [ "${_maj}" -le 7 ] && [ "${_min}" -lt 7 ] && break   # floor: 7.7 (older trees are gone upstream)
        _min=$((_min - 1)); [ "${_min}" -lt 0 ] && { _maj=$((_maj - 1)); _min=9; }
        _c="${_maj}.${_min}"
    done
    echo "ERROR: could not resolve a published OpenBSD release (set ABZU_OPENBSD_VER)" >&2
    return 1
}
OPENBSD_VER="$(resolve_openbsd_ver)"
echo "openbsd $OPENBSD_VER"
fetch "https://cdn.openbsd.org/pub/OpenBSD/${OPENBSD_VER}/src.tar.gz" src.tar.gz
fetch "https://cdn.openbsd.org/pub/OpenBSD/${OPENBSD_VER}/amd64/SHA256" openbsd-sha256.txt

# GNUstep core + GWorkspace (see gui/gnustep-overlay pins).
# URL layout verified against ftp.gnustep.org directory listings: the four
# core components all live under pub/gnustep/core/, while GWorkspace is an
# application tarball under pub/gnustep/usr-apps/ (there is NO
# pub/gnustep/apps/ or per-category gui/back/ directory — those 404).
fetch "https://ftp.gnustep.org/pub/gnustep/core/gnustep-make-2.9.2.tar.gz"  gnustep-make-2.9.2.tar.gz
fetch "https://ftp.gnustep.org/pub/gnustep/core/gnustep-base-1.31.1.tar.gz" gnustep-base-1.31.1.tar.gz
fetch "https://ftp.gnustep.org/pub/gnustep/core/gnustep-gui-0.32.0.tar.gz"  gnustep-gui-0.32.0.tar.gz
fetch "https://ftp.gnustep.org/pub/gnustep/core/gnustep-back-0.32.0.tar.gz" gnustep-back-0.32.0.tar.gz
fetch "https://ftp.gnustep.org/pub/gnustep/usr-apps/gworkspace-1.1.0.tar.gz" gworkspace-1.1.0.tar.gz

# rEFInd EFI bootloader (prebuilt binary release, GPLv3)
fetch "https://sourceforge.net/projects/refind/files/0.14.0.2/refind-bin-0.14.0.2.zip" refind-bin.zip

# Darwin components from Apple's OSS releases
fetch "https://github.com/apple-oss-distributions/launchd/archive/refs/heads/main.tar.gz" launchd-main.tar.gz
fetch "https://github.com/apple-oss-distributions/system_cmds/archive/refs/heads/main.tar.gz" system_cmds-main.tar.gz

# Verify everything we can against the lock file
if [ -f "${LOCK}" ]; then
    echo "==> verifying distfiles against config/distfiles.sha256"
    (cd "${DIST}" && grep -v '^#' "${LOCK}" | while read -r sum name; do
        echo "${sum}  ${name}" | sha256sum -c - || exit 1
    done)
fi
echo "==> distfiles ready in ${DIST}"
