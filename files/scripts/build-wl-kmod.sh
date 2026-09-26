#!/usr/bin/env bash
set -euo pipefail

# Build the Broadcom wl kernel module for the target kernel during the
# image build. The script:
#   1. installs kernel-devel for the target kernel and akmod-wl, with
#      scriptlets suppressed so dnf does not try to trigger a build for
#      the container's host kernel.
#   2. invokes /usr/sbin/akmods AS ROOT. akmods internally drops to the
#      unprivileged 'akmods' user for compilation, then re-elevates to
#      install the resulting kmod RPM.
#   3. verifies the kmod RPM was produced.

echo "=== Installing kernel-devel and akmod-wl ==="
dnf install -y \
    --setopt=tsflags=noscripts \
    --setopt=install_weak_deps=False \
    akmod-wl \
    kernel-devel-matched

# Determine the kernel version we are building for. The container's
# uname -r reports the host kernel, which is not what we want. Ask RPM
# for the highest installed kernel package instead.
TARGET_KVER=$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n1)
if [ -z "${TARGET_KVER}" ]; then
    echo "ERROR: could not determine target kernel version" >&2
    rpm -q kernel
    exit 1
fi
echo "Target kernel: ${TARGET_KVER}"

echo "=== Building wl kmod for ${TARGET_KVER} ==="
# Run as root. akmods handles the privilege switch internally.
/usr/sbin/akmods --force --kernels "${TARGET_KVER}"

echo "=== Verifying kmod-wl was produced ==="
if ! ls -1 /var/cache/akmods/wl/*.rpm >/dev/null 2>&1; then
    echo "ERROR: akmods did not produce any kmod-wl RPMs" >&2
    ls -la /var/cache/akmods/wl/ 2>&1 || true
    exit 1
fi

echo "=== Installing kmod-wl RPM ==="
# akmods places the built RPM in /var/cache/akmods/wl/. Install it so
# it lands in the image's package set.
dnf install -y --setopt=tsflags=noscripts /var/cache/akmods/wl/*.rpm

echo "=== wl kmod built and installed ==="
ls -la /var/cache/akmods/wl/*.rpm
