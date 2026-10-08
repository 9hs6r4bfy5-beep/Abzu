# rootfs.nix — merge kernel + userland + gui + packages into one
# Darwin-conformant root filesystem tree, exactly the layout XNU and launchd
# expect at boot (same contract as scripts/assemble-rootfs.sh in the Makefile
# pipeline).
{ lib, stdenvNoCC, runCommand, pkgs, kernel, userland, gui, packages, efistub, cuneiform-input, phase5-configs, packages-shelf }:

runCommand "abzu-rootfs-intel" {
  buildInputs = [ kernel userland gui packages cuneiform-input ];   # realised into the sandbox
  pathsToLink = [ "/bin" "/sbin" "/usr/bin" "/usr/sbin" "/usr/lib"
                  "/usr/local/archives" "/Library" "/System" "/Applications" ];
  meta.description = "Abzu x86_64 root filesystem staging tree (kernel + OpenBSD userland + GNUstep GUI + shelf)";
} ''
  set -e

  # ---- merged component trees ---------------------------------------------
  cp -r --no-preserve=ownership ${kernel}/.   $out/
  cp -r --no-preserve=ownership ${userland}/. $out/
  cp -r --no-preserve=ownership ${gui}/.      $out/
  cp -r --no-preserve=ownership ${packages}/. $out/

  # ---- ABZU CORE FEATURES: Cuneiform Input ---------------------------------
  echo "==> Installing Abzu Cuneiform input system..."
  cp -r --no-preserve=ownership ${cuneiform-input}/Library $out/
  cp -r --no-preserve=ownership ${cuneiform-input}/bin $out/

  # ---- Darwin skeleton directories (assemble-rootfs.sh parity) ------------
  mkdir -p $out/{dev,home,proc,Volumes,var/{db,log,tmp}} \
           $out/System/Library/{Kernels,LaunchDaemons,LaunchAgents} \
           $out/Library/{LaunchDaemons,Preferences,Themes} \
           $out/Users/Virtual $out/usr/{lib,share,local/archives}

  # ---- fstab ---------------------------------------------------------------
  cat > $out/etc/fstab <<'FSTAB'
# device    mount  fstype  options            dump pass
/dev/disk/slices/root  /     hfsfs   rw,noatime,journal   0 0
/dev/disk/slices/data  /Users hfsfs  rw,noatime,journal   0 0
archives               /usr/local/archives cd9660 ro 0 0
FSTAB

  # ---- launchd jobs from the homelab manifest (rc.conf replacement) -------
  ${pkgs.python3}/bin/python3 - $out <<'PY'
import json, os, sys, glob, plistlib
out = sys.argv[1]
outdir = os.path.join(out, "Library", "LaunchDaemons")
os.makedirs(outdir, exist_ok=True)
n = 0
for f in glob.glob(os.path.join(out, "usr/local/archives/manifests", "*homelab*.json")):
    d = json.load(open(f))
    for p in d["packages"]:
        label = f"com.abzu.homelab.{p['name'].replace('-','_')}"
        plistlib.dump({
            "Label": label,
            "ProgramArguments": [f"/usr/sbin/{p['name']}"],
            "RunAtLoad": False, "KeepAlive": True,
            "SandboxProfile": "/etc/sandbox.d/abzu-services.sb",
            "Note": p.get("role", ""),
        }, open(os.path.join(outdir, label + ".plist"), "wb"))
        n += 1
print(f"==> generated {n} launchd plists")
PY

  # ---- default prefs → AbzuAqua theme --------------------------------------
  cat > $out/Library/Preferences/com.abzu.gui.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>GSThemeName</key><string>AbzuAqua</string>
  <key>GAFontAntialiasing</key><true/>
  <key>DefaultShellMenu</key><string>/Library/Application Support/AbzuShell/shell-menu.json</string>
</dict></plist>
PLIST

  # ---- boot args baked for the release profile (kernel/config/build-profiles.md)
  echo 'keepsyms=0 abzu_wx=1 cluster_log_level=3 -wegoff' > $out/etc/abzu-boot-args

  # ---- permissions hygiene (OpenBSD-style tightening) -----------------------
  chmod 600 $out/etc/master.passwd 2>/dev/null || true
  chmod 1777 $out/var/tmp 2>/dev/null || true

  # ---- record whether a genuine kernel is present ---------------------------
  if [ -f $out/System/Library/Kernels/kernel ]; then
    echo "kernel: present ($(wc -c < $out/System/Library/Kernels/kernel) bytes)" > $out/.abzu-image-kind
  else
    echo "installer-skeleton" > $out/.abzu-image-kind
  fi

  # 5. PHASE 5: USE CASE OPTIMIZATION DEFAULTS
  echo "==> Staging Phase 5 use-case optimizations..."

  # Copy user skeleton files (vdirsyncer, khal, apple2pi)
  mkdir -p $out/etc/skel/.config
  cp -r --no-preserve=ownership ${phase5-configs}/etc-skel/.config/. \
                               $out/etc/skel/.config/

  # Copy Stellarium defaults to the Darwin application support location
  mkdir -p $out/Library/Application\ Support/Stellarium
  cp ${phase5-configs}/stellarium-defaults/config.ini \
     $out/Library/Application\ Support/Stellarium/

  # Copy Quiver defaults to a shared system location
  mkdir -p $out/usr/share/abzu/defaults
  cp ${packages-shelf}/gaming/quiver-defaults.json $out/usr/share/abzu/defaults/

  # Set permissions
  find $out -type d -exec chmod 755 {} \;
  find $out -type f -exec chmod 644 {} \;
  find $out/bin -type f -exec chmod 755 {} \;
''

# ---- Phase 5 variant: abzu-rootfs ------------------------------------------
# Slim staging tree merging xnu-kernel + openbsd-userland + gui-core with the
# Phase 5 use-case optimization defaults (etck skel, Stellarium, Quiver).
{ lib, stdenvNoCC, runCommand, xnu-kernel, openbsd-userland, gui-core, cuneiform-input, packages-shelf, phase5-configs }:

runCommand "abzu-rootfs" {
  pathsToLink = [ "/bin" "/Library" "/usr" "/etc" ];
} ''
  set -e
  mkdir -p $out

  # ... [Existing kernel, userland, gui-core copies] ...

  # 5. PHASE 5: USE CASE OPTIMIZATION DEFAULTS
  echo "==> Staging Phase 5 use-case optimizations..."
  
  # Copy user skeleton files (vdirsyncer, khal, apple2pi)
  mkdir -p $out/etc/skel/.config
  cp -r ${ph…rium defaults
  mkdir -p $out/Library/Application\ Support/Stellarium
  cp ${phase5-configs}/stellarium-defaults/config.ini $out/Library/Application\ Support/Stellarium/
  
  # Copy Quiver defaults to a shared system location
  mkdir -p $out/usr/share/abzu/defaults
  cp ${packages-shelf}/gaming/quiver-defaults.json $out/usr/share/abzu/defaults/

  # Set permissions
  find $out -type d -exec chmod 755 {} \;
  find $out -type f -exec chmod 644 {} \;
  find $out/bin -type f -exec chmod 755 {} \;
''
