#!/usr/bin/env bash
set -euo pipefail

# The RPM Fusion akmod-wl package's %post scriptlet refuses to build the
# kernel module as root. This is intentional: akmodsbuild must be run as the
# unprivileged 'akmods' user that the akmods package creates.
#
# Strategy:
#   1. Install akmod-wl with all scriptlets suppressed (--setopt=tsflags=noscripts)
#      so dnf does not attempt the root build and abort the transaction.
#   2. Invoke /usr/sbin/akmods as the akmods user to build the kmod(s) for the
#      installed kernel-devel package.
#   3. Verify that the resulting kmod RPMs exist.

echo "=== Installing akmod-wl (scriptlets suppressed) ==="
dnf install -y \
    --setopt=tsflags=noscripts \
    --setopt=install_weak_deps=False \
    akmod-wl

echo "=== Building wl kmod as the akmods user ==="
# The 'akmods' user is created by the akmods package (UID 950).
# runuser is part of util-linux and is present on Fedora.
runuser -u akmods -- /usr/sbin/akmods --force

echo "=== Verifying kmod-wl was produced ==="
if ! ls -1 /var/cache/akmods/wl/*.rpm >/dev/null 2>&1; then
    echo "ERROR: akmods did not produce any kmod-wl RPMs" >&2
    ls -la /var/cache/akmods/wl/ 2>&1 || true
    exit 1
fi

echo "=== wl kmod built successfully ==="
ls -la /var/cache/akmods/wl/*.rpm
