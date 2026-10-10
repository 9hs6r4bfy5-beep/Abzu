# openbsd-userland.nix — OpenBSD-derived tools rebuilt as Mach-O for Abzu.
#
# The heavy per-tool porting logic lives in ../../userland/build-openbsd-tools.sh
# (fetch → port → stage). This derivation NEVER invokes that script: it always
# produces the "staging skeleton" (etc overlay + import manifests + STATUS
# marker) so the ISO pipeline can assemble an installer image on any host.
# The actual Mach-O binaries are produced by running the driver *outside* Nix
# (build/Makefile: `make userland`), against a writable distfiles/stage tree;
# the binary swap-in happens when the same rootfs derivation is built from
# those externally staged artifacts.
#
# FIX (build failure 2026-10-11, same class as gnustep.nix / abzu-gui-core):
# the previous version invoked ${repoRoot}/userland/build-openbsd-tools.sh
# from inside the Nix sandbox, gated on a runtime `uname -s` check. Two bugs:
#   1. build-openbsd-tools.sh derives its paths from its own file location
#      (ROOT="$(dirname $0)"; DIST="$ROOT/distfiles"; OUT defaults to
#      "$ROOT/out"; STAGE defaults to "$ROOT/stage"), then unconditionally
#      does `mkdir -p` on all three. Calling the copy of the
#      script that lives in the read-only source store path made it try to
#      create userland/distfiles|out|stage inside /nix/store — which is
#      immutable — aborting the builder with exit 1 under `set -eu` and
#      cascading into rootfs-intel and iso-intel ("Permission denied").
#      Note also that the environment override was spelled ABZU_DISTFILES,
#      but the script reads DIST, so even setting it would not have helped.
#   2. `uname -s` reports the *host* kernel even for cross-Darwin builds on a
#      Linux builder, so this Darwin code path ran (and failed) on Linux too.
#      Worse, the script fetches from cdn.openbsd.org over the network, which
#      the sandbox forbids regardless. The fix: drop the in-sandbox call and
#      the misleading uname branch entirely; the staging skeleton below is
#      what ships from Nix, and the Mach-O binaries come from an external
#      Darwin build of the driver (build/Makefile: `make userland`).
{ lib, stdenvNoCC, runCommand, srcInfo, manifest, skipList, compatSrc, etcOverlay, repoRoot ? null }:

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

  # Staging skeleton only. We must NOT invoke userland/build-openbsd-tools.sh
  # here — it derives its distfiles/out/stage directories from its own file
  # location, so running it from the read-only source store path tries to
  # mkdir inside /nix/store ("Permission denied"), and its cdn.openbsd.org
  # fetches would fail in the sandbox anyway (see header FIX note). Produce
  # the Mach-O binaries by running the driver outside Nix instead:
  #   make -C build userland        # writable DIST/OUT/STAGE in the work tree
  echo "NOTE: staging skeleton — no Mach-O binaries shipped from Nix." > $out/STATUS
  echo "Run userland/build-openbsd-tools.sh outside Nix (build/Makefile:" >> $out/STATUS
  echo "'make userland') on a Darwin builder to obtain Mach-O binaries," >> $out/STATUS
  echo "or pass a prebuilt userland into the rootfs derivation." >> $out/STATUS

  cat > $out/var/db/abzu/userland.json <<JSON
{ "openbsd": "${srcInfo.openbsdSnap}", "toolCount": $(grep -c '^[a-z]' $out/etc/abzu-tools.manifest || echo 0), "staged": "skeleton" }
JSON
''
