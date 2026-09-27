#!/usr/bin/env bash
set -euo pipefail

# Ensure IBus daemon is running
if ! pgrep -x ibus-daemon >/dev/null 2>&1; then
    ibus-daemon -drx
    sleep 1
fi

# Switch to cuneiform engine
ibus engine cuneiform
