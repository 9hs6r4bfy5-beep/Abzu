#!/bin/sh
# Abzu — OpenBSD userland → Darwin import & Mach-O rebuild driver
# ---------------------------------------------------------------------------
# Strategy ("fill in the blanks with OpenBSD", unlike ravynOS's FreeBSD):
#   1. `fetch`  : pull OpenBSD source tarballs (-current snapshot) + Darwin
#                 components from opensource.apple.com into distfiles/.
#   2. `port`   : apply the per-tool shim patches in mach_compat/ and rebuild
#                 each tool as Mach-O against the Darwin system headers,
#                 using a clang that targets x86_64-apple-darwin.
#   3. `stage`  : install results under out/{bin,sbin,usr/{bin,sbin},etc}.
#
# Only *userland* is imported from OpenBSD. The kernel stays XNU. Tools that
# hard-depend on OpenBSD kernel interfaces (pf(4) ioctl ABI, bio*, slog, ddb)
# are listed in import/skip.txt and NOT ported; their functionality is covered
# later by Darwin-native equivalents (see docs/ROADMAP.md).
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="${DIST:-${ROOT}/distfiles}"
OUT="${OUT:-${ROOT}/out}"
STAGE="${STAGE:-${ROOT}/stage}"
# Version-agnostic default: take the newest release dir on cdn.openbsd.org
# whose amd64/SHA256 manifest exists (same rule as fetch-distfiles.sh's
# resolver; "source/" is OpenBSD's alias for the per-release source tree).
# Override with OPENBSD_SNAP=<url>.
_obver_latest() {
    _c=$(curl -fSL --retry 3 "https://cdn.openbsd.org/pub/OpenBSD/" 2>/dev/null \
         | grep -oE 'href="[0-9]+\.[0-9]+/"' | grep -oE '[0-9]+\.[0-9]+' \
         | sort -t. -k1,1n -k2,2n | tail -1) || true
    while [ -n "${_c:-}" ]; do
        if curl -fsIL --max-time 15 \
           "https://cdn.openbsd.org/pub/OpenBSD/${_c}/amd64/SHA256" >/dev/null 2>&1; then
            echo "${_c}"; return 0
        fi
        _maj=${_c%.*}; _min=${_c#*.}
        [ "${_maj}" -le 7 ] && [ "${_min}" -lt 7 ] && break
        _min=$((_min - 1)); [ "${_min}" -lt 0 ] && { _maj=$((_maj - 1)); _min=9; }
        _c="${_maj}.${_min}"
    done
    return 1
}
OPENBSD_VER_DEFAULT="$(_obver_latest || echo 7.9)"
OPENBSD_SNAP="${OPENBSD_SNAP:-https://cdn.openbsd.org/pub/OpenBSD/${OPENBSD_VER_DEFAULT}/source}"
MANIFEST="${ROOT}/import/tools.manifest"

usage() { echo "usage: $0 {fetch|port|stage|all} [tool...]" >&2; exit 1; }
CMD="${1:-all}"; shift || true

mkdir -p "${DIST}" "${OUT}" "${STAGE}"

do_fetch() {
    echo "==> fetching OpenBSD ${OPENBSD_SNAP} sources per manifest"
    while read -r name _rest; do
        case "${name}" in ''|'#'*) continue ;; esac
        f="src-${name}.tgz"
        [ -f "${DIST}/${f}" ] && { echo "    cached ${f}"; continue; }
        curl -fSL --retry 3 -o "${DIST}/src.tar.gz.part" \
            "${OPENBSD_SNAP}/src.tar.gz" && mv "${DIST}/src.tar.gz.part" "${DIST}/src.tar.gz"
        curl -fSL -o "${DIST}/sha256.sig" "${OPENBSD_SNAP}/sha256.sig" || true
        break
    done < "${MANIFEST}"
    echo "==> fetching Darwin releases index (opensource.apple.com)"
    curl -fsSL -o "${DIST}/apple-releases.json" \
        "https://api.github.com/repos/apple-oss-distributions/distribution-matrix-xnu/releases" || \
        echo "    !! could not fetch release index (offline? run again later)"
}

do_port() {
    [ "$(uname -s)" = "Darwin" ] || echo "WARN: non-Darwin host; Mach-O link will be skipped"
    cd "${DIST}"

    # FAST TRACK: Build portable doas immediately without needing the massive OpenBSD src.tar.gz
    for want in "$@"; do
        if [ "${want}" = "doas" ]; then
            echo "==> porting portable OpenBSD doas to Darwin"
            DOAS_DIR="${DIST}/OpenDoas"
            if [ ! -d "${DOAS_DIR}" ]; then
                echo "    fetching portable doas source..."
                git clone https://github.com/Duncaen/OpenDoas.git "${DOAS_DIR}"
            fi
            cd "${DOAS_DIR}"
            
            # CRITICAL: Run configure to generate config.mk before calling make
            ./configure
            
            make clean >/dev/null 2>&1 || true
            
            # Use bison with yacc compatibility flags to bypass macOS xcode-select errors
            if make YACC="${YACC:-bison}" YACCFLAGS="-y -d" 2>/dev/null; then
                echo "    built successfully via make"
            else
                echo "    applying manual yacc compatibility build..."
                ${YACC:-bison} -y -d parse.y
                mv -f y.tab.c parse.c
                mv -f y.tab.h parse.h
                make
            fi
            
            mkdir -p "${OUT}/usr/bin" "${OUT}/etc"
            cp doas "${OUT}/usr/bin/"
            cp doas.conf.sample "${OUT}/etc/doas.conf.sample"
            cd "${DIST}"
            continue
        fi
    done

    # Now proceed with the rest of the tools that require the OpenBSD source tree
    [ -f src.tar.gz ] || { echo "!! run '$0 fetch' first for other tools"; return 0; }
    tar xzf src.tar.gz
    cd usr/src

    for want in "$@"; do
        [ "${want}" = "doas" ] && continue # Skip doas, already built above
        
        grep -qx "${want}" ../../import/skip.txt 2>/dev/null && {
            echo "==> SKIP ${want} (OpenBSD kernel coupling; see skip.txt)"; continue; }
        
        echo "==> porting ${want} to Mach-O / Darwin"
        SRCDIR="$(find . -type d \( -path "./bin/${want}" -o -path "./usr.bin/${want}" \
                 -o -path "./sbin/${want}" -o -path "./usr.sbin/${want}" \
                 -o -path "./lib/libc" -a -name libc \) | head -1)"
        [ -n "${SRCDIR}" ] || { echo "    !! ${want}: source dir not found in tree"; continue; }

        SHIM="${ROOT}/mach_compat/${want}.patch"
        if [ -f "${SHIM}" ]; then
            (cd "${SRCDIR%/*}" && patch -p1 < "${SHIM}") || echo "    !! shim failed for ${want}"
        fi

        if [ "$(uname -s)" = "Darwin" ]; then
            ( cd "${SRCDIR}" && \
              make CC="clang -target x86_64-apple-darwin23.0.0 -mmacosx-version-min=13.0" \
                   CFLAGS="-D__COPYRIGHT\(c\)= -fno-common -O2 -pipe" \
                   LIBS="" BSDHOSTCFLAGS="" PROG=${want} ) \
              && DESTDIR="${STAGE}" make -C "${SRCDIR}" INSTALL="install -c -m 755" install || \
              cp "${SRCDIR}/${want}" "${STAGE}/bin/" 2>/dev/null || true
        else
            echo "    (cross stage: handled by nix build .#openbsd-userland)"
        fi
    done
}

do_stage() {
    echo "==> staging filesystem layout into ${OUT}"
    mkdir -p "${OUT}"/{bin,sbin,etc,usr/bin,usr/sbin,var/db}
    [ -d "${STAGE}/bin" ] && cp -a "${STAGE}/bin/." "${OUT}/bin/" 2>/dev/null || true
    find "${STAGE}" -type f -perm -u+x -print 2>/dev/null | while read -r f; do
        b="$(basename "$f")"
        case "${b}" in sshd|ntpd|relayd|cron|syslogd) cp "$f" "${OUT}/sbin/" ;; *) cp "$f" "${OUT}/usr/bin/" ;; esac
    done
    cp -a "${ROOT}/etc/." "${OUT}/etc/"
    echo "==> staged $(find "${OUT}" -type f | wc -l | tr -d ' ') files"
}

case "${CMD}" in
    fetch) do_fetch ;;
    port)  [ $# -gt 0 ] && do_port "$@" || do_port $(grep -v '^#' "${MANIFEST}" | awk '{print $1}' | grep -v '^$') ;;
    stage) do_stage ;;
    all)   do_fetch; do_port $(grep -v '^#' "${MANIFEST}" | awk '{print $1}' | grep -v '^$'); do_stage ;;
    *)     usage ;;
esac
