#!/usr/bin/env bash
set -euo pipefail

echo "--- Enabling COPR repositories for fedora-44-x86_64 ---"

# The base image reports its OS ID as "secureblue", so dnf's auto-detection
# tries to enable COPRs for "secureblue-44-x86_64", which does not exist.
# We force the correct chroot explicitly.

dnf5 copr enable -y bieszczaders/kernel-cachyos-addons fedora-44-x86_64
dnf5 copr enable -y atim/starship fedora-44-x86_64

echo "--- COPRs enabled ---"
