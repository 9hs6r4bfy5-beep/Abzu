# openbsd-userland.nix — OpenBSD-derived tools rebuilt as Mach-O for Abzu.
#
# The heavy per-tool porting logic lives in ../../userland/build-openbsd-tools.sh
# (fetch → port → stage). This derivation wraps it:
#   * on a Darwin builder: runs the script for real, producing Mach-O binaries;
#   * on Linux: produces the "staging skeleton" (scripts + etc overlay) so the
#     ISO pipeline can still assemble an installer image; the binary swap-in
#     happens when the same rootfs derivation is built on a Darwin builder.
{ lib, stdenvNoCC, runCommand, srcInfo, manifest, skipList, compatSrc, etcOverlay, repoRoot }:

runCommand "abzu-openbsd-userland-${srcInfo.openbsdSnap}" {
  inherit manifest skipList compatSrc etcOverlay;
  meta.description = "OpenBSD ${srcInfo.openbsdSnap}-derived userland tools, Mach-O rebuild";
} ''
  set -e
  mkdir -p $out/{bin,sbin,usr/bin,usr/sbin,usr/lib,etc,var/db/abzu}

  # etc overlay (doas.conf, master.passwd skeleton, ...) — always shipped.
  cp -r ${etcOverlay}/. $out/etc/
  chmod 600 $out/etc/master.passwd 2>/dev/null || true

  # Import manifests travel with the package so the Darwin-side build driver
  # and first-boot installer can re-resolve them.
  cp ${manifest}  $out/etc/abzu-tools.manifest
  cp ${skipList}  $out/etc/abzu-skip.txt
  cp ${compatSrc} $out/etc/abzu-compat.c

  if [ "$(uname -s)" = "Darwin" ]; then
    # Real cross-port: invoke the repo's driver against our distfiles cache.
    DIST="''${ABZU_DISTFILES:-./distfiles}" OUT="$out" \
      ${repoRoot}/userland/build-openbsd-tools.sh all || exit 1
  else
    echo "NOTE: Linux host — shipping userland staging skeleton." > $out/STATUS
    echo "Rebuild this derivation on a Darwin builder (or via the container" >> $out/STATUS
    echo "path used by xnu.nix) to obtain Mach-O binaries." >> $out/STATUS
  fi

  cat > $out/var/db/abzu/userland.json <<JSON
{ "openbsd": "${srcInfo.openbsdSnap}", "toolCount": $(grep -c '^[a-z]' $out/etc/abzu-tools.manifest || echo 0) }
JSON
''
