# build/derivations/rootfs-slim.nix
# Slim "abzu-rootfs" Phase 5 staging tree: merges xnu-kernel + openbsd-userland
# + gui-core + cuneiform-input with the Phase 5 use-case optimization defaults
# (etc/skel, Stellarium, Quiver). Lives in its own module because a Nix file
# exports exactly one top-level expression and pkgs.callPackage therefore
# cannot reach rootfs.nix's second function (abzu-rootfs-intel).
# Takes the components by their flake-level attribute names and merges them
# via buildInputs + pathsToLink plus explicit copies of the trees that carry
# no linkable top-level dirs (kernel → /System, gui → /Applications).
{ lib, stdenvNoCC, runCommand, xnu-kernel, openbsd-userland, gui-core, cuneiform-input, packages-shelf, phase5-configs }:

runCommand "abzu-rootfs" {
  # realised into the sandbox; /bin, /Library, /usr, /etc merge automatically
  buildInputs = [ openbsd-userland cuneiform-input ];
  pathsToLink = [ "/bin" "/Library" "/usr" "/etc" ];
  meta.description = "Abzu slim root filesystem staging tree (kernel + OpenBSD userland + GNUstep GUI + Phase 5 use-case defaults)";
} ''
  set -e
  mkdir -p $out

  # ---- component trees ------------------------------------------------------
  # Kernel payload (System/Library/Kernels/kernel + bootstrap artifacts):
  # /System is not in pathsToLink, so copy explicitly.
  cp -r --no-preserve=ownership ${xnu-kernel}/System $out/
  mkdir -p $out/bootstrap
  cp -r --no-preserve=ownership ${xnu-kernel}/bootstrap/. $out/bootstrap/

  # GUI core: /Library themes + shell menu arrive via pathsToLink;
  # /Applications and /usr/local/share/gnustep need explicit copies.
  cp -r --no-preserve=ownership ${gui-core}/Applications $out/
  mkdir -p $out/usr/local/share
  cp -r --no-preserve=ownership ${gui-core}/usr/local/share/gnustep \
                                 $out/usr/local/share/gnustep

  # Userland (/bin, /sbin, /usr, /etc) and the cuneiform input method
  # (/bin/cuneiform-toggle, /Library/Keyboard Layouts) merged via buildInputs.

  # ---- Darwin skeleton directories ------------------------------------------
  mkdir -p $out/{dev,home,Volumes,var/{db,log,tmp}} \
           $out/System/Library/{LaunchDaemons,LaunchAgents} \
           $out/Library/{LaunchDaemons,Preferences,Themes} \
           $out/Users/Virtual $out/usr/{lib,share,local/archives} \
           $out/etc $out/bin

  # ---- fstab ----------------------------------------------------------------
  cat > $out/etc/fstab <<'FSTAB'
# device    mount  fstype  options            dump pass
/dev/disk/slices/root  /     hfsfs   rw,noatime,journal   0 0
/dev/disk/slices/data  /Users hfsfs  rw,noatime,journal   0 0
archives               /usr/local/archives cd9660 ro 0 0
FSTAB

  # ---- default prefs → AbzuAqua theme -----------------------------------------
  cat > $out/Library/Preferences/com.abzu.gui.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>GSThemeName</key><string>AbzuAqua</string>
  <key>GAFontAntialiasing</key><true/>
  <key>DefaultShellMenu</key><string>/Library/Application Support/AbzuShell/shell-menu.json</string>
</dict></plist>
PLIST

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

  # ---- record whether a genuine kernel is present ----------------------------
  if [ -f $out/System/Library/Kernels/kernel ]; then
    echo "kernel: present ($(wc -c < $out/System/Library/Kernels/kernel) bytes)" > $out/.abzu-image-kind
  else
    echo "installer-skeleton" > $out/.abzu-image-kind
  fi

  # Set permissions
  find $out -type d -exec chmod 755 {} \;
  find $out -type f -exec chmod 644 {} \;
  find $out/bin -type f -exec chmod 755 {} \;
  # re-apply sensitive bits clobbered by the blanket 644 sweep
  chmod 600 $out/etc/master.passwd 2>/dev/null || true
  chmod 1777 $out/var/tmp 2>/dev/null || true
''
