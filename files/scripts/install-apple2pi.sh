#!/usr/bin/env bash
set -euo pipefail

echo "--- Building Apple II Pi ---"

WORKDIR=/tmp/apple2pi
rm -rf "${WORKDIR}"

git clone --depth=1 https://github.com/dschmenk/apple2pi.git "${WORKDIR}"
cd "${WORKDIR}/src"

# Build everything in one pass. The default target compiles every binary,
# including fusea2pi, a2pid, dskread, dskwrite, nibread, etc.
make

echo "--- Installing Apple II Pi binaries ---"

# Install userspace utilities.
install -d /usr/local/bin
install -m 0755 \
    a2joy a2joymou a2joypad a2mon a2term fusea2pi a2pidcmd \
    dskread dskwrite bload brun nibread dskformat eddread \
    a2mount a2setvd \
    /usr/local/bin/

# Install the daemon.
install -d /usr/local/sbin
install -m 0755 a2pid /usr/local/sbin/

# Install shared data files.
install -d /usr/share/a2pi
cp -R ../share/. /usr/share/a2pi/

# Convenience symlinks expected by the Apple II Pi ROM.
ln -sf /usr/share/a2pi/A2PI-1.8.PO /usr/share/a2pi/A2VD1.PO
ln -sf /usr/share/a2pi/UTILS.PO     /usr/share/a2pi/A2VD2.PO

# Enable the systemd unit if present. Do not fail the build if the unit
# is missing or cannot be enabled in the container environment.
if [ -f /usr/share/a2pi/a2pi.service ]; then
    systemctl enable --system /usr/share/a2pi/a2pi.service || \
        echo "WARNING: could not enable a2pi.service (continuing)"
fi

echo "--- Apple II Pi installation complete ---"
