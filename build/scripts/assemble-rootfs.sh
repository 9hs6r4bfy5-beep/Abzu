#!/bin/sh
# assemble-rootfs.sh — turn the staged outputs of kernel/userland/gui/packages
# into a Darwin-conformant root filesystem tree ready for ISO wrapping.
#
# Layout produced (matches what XNU + launchd expect on boot):
#   /                HFS+ root, case-insensitive, journaled in final image
#   /System/Library/Kernels/kernel        ← from stage root (kernel build)
#   /sbin/launchd                         ← Darwin launchd release (fetched)
#   /bin,/usr/bin,/usr/sbin               ← OpenBSD-derived Mach-O tools
#   /Library/{Themes,Application Support} ← GNUstep + AbzuAqua + shelf apps
#   /usr/local/archives                   ← history-archives (read-only mount later)
#   /etc                                  ← doas.conf, master.passwd skeleton, fstab
#   /EFI                  (in the ISO's ESP image, not here)
set -eu
STAGE="${1:?usage: $0 <staging-dir>}"
[ -d "${STAGE}" ] || { echo "!! ${STAGE} missing; run earlier stages first" >&2; exit 1; }

echo "==> assembling rootfs in ${STAGE}"

# 1. Darwin skeleton directories
mkdir -p "${STAGE}"/{bin,sbin,dev,etc,home,proc,System/Library/Kernels,\
System/Library/LaunchDaemons,System/Library/LaunchAgents,\
Library/LaunchDaemons,Library/Preferences,Library/Themes,\
Applications,Users/Virtual,Volumes,usr/{bin,lib,sbin,local/archives,share},var/{db,log,tmp}}

# 2. Kernel must exist or we are only packaging a live-image skeleton
if [ ! -f "${STAGE}/System/Library/Kernels/kernel" ]; then
    echo "WARN: no kernel mach-o staged (expected on Linux hosts)."
    echo "      ISO will be built as 'installer-skeleton' until kernel stage runs on Darwin."
fi

# 3. fstab + static config
cat > "${STAGE}/etc/fstab" <<'FSTAB'
# device    mount  fstype  options            dump pass
/dev/disk/slices/root  /     hfsfs   rw,noatime,journal   0 0
/dev/disk/slices/data  /Users hfsfs  rw,noatime,journal   0 0
archives               /usr/local/archives cd9660 ro 0 0
FSTAB

cp "${STAGE}/etc/doas.conf" /dev/null 2>/dev/null \
  || cp "$(dirname "$0")/../../userland/etc/doas.conf" "${STAGE}/etc/" 2>/dev/null || true

# 4. Generate launchd jobs from homelab manifest (rc.conf replacement)
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python3 - "${STAGE}" "${REPO_ROOT}/packages/homelab/manifest.json" <<'PY' || echo "WARN: launchd plist generation skipped (python3 missing)"
import json, os, sys, plistlib
stage, mani = sys.argv[1], sys.argv[2]
if os.path.exists(mani):
    d = json.load(open(mani))
    outdir = os.path.join(stage, 'Library', 'LaunchDaemons')
    os.makedirs(outdir, exist_ok=True)
    for p in d['packages']:
        label = f"com.abzu.homelab.{p['name'].replace('-','_')}"
        plist = {
            'Label': label,
            'ProgramArguments': [f"/usr/sbin/{p['name']}"],
            'RunAtLoad': False,
            'KeepAlive': True,
            'SandboxProfile': '/etc/sandbox.d/abzu-services.sb',
            'Note': p.get('role', ''),
        }
        with open(os.path.join(outdir, label + '.plist'), 'wb') as f:
            plistlib.dump(plist, f)
    print(f"==> generated {len(d['packages'])} launchd plists")
else:
    print("no homelab manifest found at expected paths")
PY

# 5. Default preferences pointing at the Aqua theme
mkdir -p "${STAGE}/Library/Preferences"
cat > "${STAGE}/Library/Preferences/com.abzu.gui.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>GSThemeName</key><string>AbzuAqua</string>
  <key>GAFontAntialiasing</key><true/>
  <key>DefaultShellMenu</key><string>/Library/Application Support/AbzuShell/shell-menu.json</string>
</dict></plist>
PLIST

# 6. permissions hygiene (OpenBSD-style: world-readable, group-tightened)
chmod 600 "${STAGE}/etc/master.passwd" 2>/dev/null || true
chmod 750 "${STAGE}/etc" 2>/dev/null || true
chmod 1777 "${STAGE}/var/tmp" "${STAGE}/tmp" 2>/dev/null || true

echo "==> rootfs assembled under ${STAGE}"
