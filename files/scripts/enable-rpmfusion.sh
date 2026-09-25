#!/usr/bin/env bash
set -euo pipefail

# Install RPM Fusion release RPMs directly.
#
# We do this here instead of using BlueBuild's built-in "nonfree: rpmfusion"
# option because that option also tries to enable the 'fedora-cisco-openh264'
# repository, which secureblue has removed for security reasons. The failed
# enable causes the entire dnf module to abort.
#
# Installing the release RPMs directly achieves the same end state (RPM Fusion
# .repo files + GPG keys in place) without touching fedora-cisco-openh264.

FEDORA_VERSION=44

echo "=== Installing RPM Fusion release RPMs (Fedora ${FEDORA_VERSION}) ==="
dnf install -y --nogpgcheck \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
echo "=== RPM Fusion release RPMs installed ==="
