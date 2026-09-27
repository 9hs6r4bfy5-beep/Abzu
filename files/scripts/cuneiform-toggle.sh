#!/usr/bin/env bash
set -euo pipefail

# IBus is a per-user daemon. It cannot be started or controlled during an
# image build (there is no D-Bus session bus and no logged-in user). The
# previous version of this script tried `ibus-daemon -drx` and
# `ibus engine cuneiform` at build time, which produced:
#
#   IBUS-CRITICAL **: ibus_bus_set_global_engine: assertion 'IBUS_IS_BUS (bus)' failed
#
# and aborted the build.
#
# The correct approach is to install a small helper and run it at session
# start via an XDG autostart entry. This script performs the installation
# only; the actual engine switch happens on first login.

echo "--- Installing Cuneiform IBus toggle ---"

install -d -m 0755 /usr/local/bin
cat > /usr/local/bin/cuneiform-toggle <<'HELPER'
#!/usr/bin/env bash
# Runs in the user session. Wait for ibus-daemon, then select cuneiform.

# Wait up to ~10 seconds for the IBus daemon to come up.
for _ in $(seq 1 20); do
    if pgrep -x ibus-daemon >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# If IBus is still not running, there is nothing useful we can do.
if ! pgrep -x ibus-daemon >/dev/null 2>&1; then
    exit 0
fi

# Only attempt to switch if the engine is registered.
if ! ibus list-engine 2>/dev/null | grep -q 'cuneiform'; then
    exit 0
fi

# Best-effort engine selection. Failure is non-fatal: the user may have
# manually switched engines, or IBus may not have finished initialising.
ibus engine cuneiform 2>/dev/null || true
HELPER
chmod 0755 /usr/local/bin/cuneiform-toggle

install -d -m 0755 /etc/xdg/autostart
cat > /etc/xdg/autostart/cuneiform-toggle.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Cuneiform IBus Engine
Comment=Select the Cuneiform IBus engine at session start
Exec=/usr/local/bin/cuneiform-toggle
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKTOP

echo "--- Cuneiform IBus toggle installed ---"
