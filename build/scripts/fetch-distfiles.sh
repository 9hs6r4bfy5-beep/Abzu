#!/bin/sh
# fetch-distfiles.sh — vendor the third-party archives the Makefile pipeline
# needs into build/distfiles/. Idempotent; verifies sha256 against lock file.
# Usage: fetch-distfiles.sh <distdir>
set -eu
DIST="${1:?usage: $0 <distdir>}"
LOCK="$(dirname "$0")/../config/distfiles.sha256"
mkdir -p "${DIST}"

fetch() { # url outfile
    local u="$1" o="${DIST}/$2"
    [ -s "$o" ] && { echo "cached  $2"; return 0; }
    echo "fetch   $2"
    curl -fSL --retry 3 -o "${o}.part" "$u" && mv "${o}.part" "$o"
}

# OpenBSD 7.6 source set (userland import)
fetch "https://cdn.openbsd.org/pub/OpenBSD/7.6/src.tar.gz" src.tar.gz
fetch "https://cdn.openbsd.org/pub/OpenBSD/7.6/amd64/SHA256" openbsd-sha256.txt

# GNUstep core + GWorkspace (see gui/gnustep-overlay pins)
fetch "https://github.com/gnustep/core/archive/refs/tags/GNUstep-make_2_9_2.tar.gz" gnustep-make-2.9.2.tar.gz || true
fetch "https://ftp.gnustep.org/pub/gnustep/core/gnustep-make-2.9.2.tar.gz"        gnustep-make-2.9.2.tar.gz
fetch "https://ftp.gnustep.org/pub/gnustep/core/gnustep-base-1.31.1.tar.gz"       gnustep-base-1.31.1.tar.gz
fetch "https://ftp.gnustep.org/pub/gnustep/core/gnustep-gui-0.32.0.tar.gz"        gnustep-gui-0.32.0.tar.gz
fetch "https://ftp.gnustep.org/pub/gnustep/core/gnustep-back-0.32.0.tar.gz"       gnustep-back-0.32.0.tar.gz
fetch "https://ftp.gnustep.org/pub/gnustep/apps/gworkspace-1.1.0.tar.gz"          gworkspace-1.1.0.tar.gz

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
