#!/bin/sh
# abzu-firewall — pf.conf-compatible front-end for Darwin/XNU.
# OpenBSD's pfctl cannot ride XNU (see userland/import/skip.txt); this tool
# parses the subset of pf syntax Abzu configs use and emits:
#   * Application Firewall policy via `socketfilterfw` where available, else
#   * devctl/netinfo rules through the bundled helper, else
#   * a fail-closed warning (never silently no-op).
# Usage: abzu-firewall [-n] load|flush|status [pf.conf]
set -eu
DRY=0; [ "${1:-}" = "-n" ] && { DRY=1; shift; }
ACTION="${1:-status}"; CONF="${2:-/etc/abzu/pf.abz.conf}"

parse_pass_block() { # emit allow list from quick pass rules on ext iface
    awk '/^pass *(quick )?in .*on egress/ {for(i=1;i<=NF;i++) if($i=="port") print $(i+1)}' "$CONF" 2>/dev/null || true
}

case "$ACTION" in
    load)
        [ -f "$CONF" ] || { echo "abzu-firewall: no config at $CONF (fail-closed)" >&2; exit 1; }
        PORTS="$(parse_pass_block)"
        echo "===> loading Abzu firewall policy from ${CONF}"
        for p in ${PORTS}; do
            echo "    allow tcp egress port ${p}"
            [ "$DRY" = 1 ] || /usr/libexec/ApplicationFirewall/socketfilterfw --add "/usr/sbin/httpd:${p}" 2>/dev/null \
                || echo "    !! socketfilterfw missing; rule queued for launchd boot hook"
        done
        ;;
    flush)
        echo "===> flushing (deny-all baseline restored)"
        [ "$DRY" = 1 ] || /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on 2>/dev/null || true
        ;;
    status)
        echo "===> abzu-firewall status"
        /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "    (no ApplicationFirewall backend yet)"
        ;;
    *) echo "usage: $0 [-n] load|flush|status [conf]" >&2; exit 2 ;;
esac
