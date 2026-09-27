# Show USB devices currently recognized by USBGuard
[group('Security')]
usbguard-list:
    @sudo usbguard list-devices

# Show USBGuard's current policy
[group('Security')]
usbguard-policy:
    @sudo cat /etc/usbguard/rules.conf

# Show current hardening status (sysctl, modprobe blacklists, etc.)
[group('Security')]
security-status:
    #!/usr/bin/bash
    set -euo pipefail
    echo "--- Active sysctl overrides ---"
    sudo sysctl --system 2>/dev/null | grep -E 'abzu|hardening' || true
    echo ""
    echo "--- Blacklisted kernel modules ---"
    grep -H '^blacklist\|^install' /etc/modprobe.d/blacklist-*.conf 2>/dev/null || true
    echo ""
    echo "--- USBGuard ---"
    systemctl is-active usbguard.service || true
