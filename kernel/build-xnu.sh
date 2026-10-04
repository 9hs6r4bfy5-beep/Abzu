#!/bin/sh
# Abzu — XNU build script (kernel/)
# ------------------------------------------------------------------
# Clones/fetches Apple's open-source XNU, applies Abzu's *minimal* patch
# set, and builds a Mach-O kernel for the target architecture.
#
# Host requirement: a Darwin machine (macOS or an existing Abzu/PureDarwin
# system). On Linux use `nix build .#xnu-kernel` from ../build for the
# containerised cross stage (best-effort; XNU prefers a Darwin host toolchain).
#
# Usage:  ./build-xnu.sh [arch] [config]
#           arch   : x86_64 (default) | i386 | arm64 | ppc
#           config : Release (default) | Debug | Development
#
# Env overrides:
#   XNU_REPO     git URL            (default: https://github.com/apple-oss-distributions/xnu.git)
#   XNU_TAG      release tag        (default: xnu-11417.101.15)
#   WORK_DIR     scratch dir        (default: ${TMPDIR:-/tmp}/abzu-xnu)
#   DST_ROOT     install root       (default: ./out)
set -eu

ARCH="${1:-x86_64}"
CONFIG="${2:-Release}"

XNU_REPO="${XNU_REPO:-https://github.com/apple-oss-distributions/xnu.git}"
XNU_TAG="${XNU_TAG:-xnu-11417.101.15}"
WORK_DIR="${WORK_DIR:-${TMPDIR:-/tmp}/abzu-xnu}"
DST_ROOT="${DST_ROOT:-$(pwd)/out}"
PATCH_DIR="$(cd "$(dirname "$0")" && pwd)/patches"

echo "==> Abzu XNU build"
echo "    arch=${ARCH} config=${CONFIG} tag=${XNU_TAG}"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "!! host is $(uname -s); XNU must be built on Darwin." >&2
    echo "!! See ../build/flake.nix for the Nix path, or run this on an Intel Mac." >&2
    exit 1
fi

# --- 1. Fetch source --------------------------------------------------------
mkdir -p "${WORK_DIR}"
if [ ! -d "${WORK_DIR}/xnu/.git" ]; then
    git clone --depth 1 --branch "${XNU_TAG}" "${XNU_REPO}" "${WORK_DIR}/xnu"
else
    git -C "${WORK_DIR}/xnu" fetch --depth 1 origin "${XNU_TAG}"
    git -C "${WORK_DIR}/xnu" checkout --detach FETCH_HEAD
fi

git -C "${WORK_DIR}/xnu" submodule update --init --depth 1 || true

# --- 2. Apply minimal Abzu patches ------------------------------------------
cd "${WORK_DIR}/xnu"
for p in "${PATCH_DIR}"/*.patch; do
    [ -e "$p" ] || continue
    name="$(basename "$p")"
    if git apply --check "$p" 2>/dev/null; then
        echo "==> applying ${name}"
        git apply "$p"
    else
        echo "==> skipping ${name} (already applied or not applicable to ${XNU_TAG})"
    fi
done

# --- 3. Build ---------------------------------------------------------------
make -j"$(sysctl -n hw.ncpu)" \
     ARCH_CONFIGS="${ARCH}" \
     KERNEL_CONFIGS="${CONFIG}" \
     ALL_BUILD_VERSION_STRING="Abzu" \
     BUILD_STRIPLIT_MASK=16 \
     || { echo "!! XNU build failed — check docs/ROADMAP.md known issues"; exit 1; }

# --- 4. Install into DST_ROOT -----------------------------------------------
mkdir -p "${DST_ROOT}/System/Library/Kernels"
for cand in \
    "build/${CONFIG}.EQUIV/kernel.${ARCH}" \
    "build/Kernel_${CONFIG}/kernel.${ARCH}" \
    "BUILD/obj/kernel.${ARCH}" ; do
    if [ -f "$cand" ]; then
        cp -f "$cand" "${DST_ROOT}/System/Library/Kernels/kernel"
        break
    fi
done
[ -f "${DST_ROOT}/System/Library/Kernels/kernel" ] \
    || { echo "!! kernel mach-o not found under build/ — inspect XNU build layout"; exit 1; }
chmod 644 "${DST_ROOT}/System/Library/Kernels/kernel"

echo "==> done: ${DST_ROOT}/System/Library/Kernels/kernel (${ARCH}/${CONFIG})"
echo "    next: make -C ../build iso   (or nix build .#iso-${ARCH})"
