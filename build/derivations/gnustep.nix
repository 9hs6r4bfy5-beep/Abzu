# gnustep.nix — GNUstep core + GWorkspace shell + AbzuAqua theme bundle.
#
# On Nixpkgs/Linux we reuse nixpkgs' GNUstep packages where they exist and
# layer the Abzu theme + shell menu on top; on a Darwin builder the tarballs
# pinned in gui/gnustep-overlay are compiled against Mach-O instead.
#
# Overlay-patch contract (audit 2026-10-10): the four patches in
# gui/gnustep-overlay/patches target gnustep-gui SOURCE files and are applied
# by gui/build-gui.sh (`git apply -p1`, fail-closed). This derivation does NOT
# postPatch them: it is a runCommand staging the theme/menu/binaries, with no
# unpacked source phase to patch. Do not duplicate the apply step here.
#
# FIX (build failure 2026-10-11, "mkdir: cannot create directory
# '/nix/store/...-...-source/gui/cache': Permission denied"): the previous
# version of this derivation invoked ${repoRoot}/gui/build-gui.sh from inside
# the Nix sandbox. build-gui.sh derives its download cache from its own file
# location (CACHE="$(dirname $0)/cache"), so calling the copy of the script
# that lives in the *read-only* source store path made it try to mkdir
# gui/cache inside /nix/store — which is immutable — and `set -e` aborted the
# builder with exit 1, cascading into rootfs-intel and iso-intel. Note also
# that the runtime branch was gated on `uname -s`, which reports the *host*
# kernel even for cross-Darwin builds on a Linux builder, so the Darwin code
# path ran (and failed) on Linux too. The fix: gate the fallback on the Nix
# eval-time platform instead, and never call build-gui.sh from within the
# sandbox — native GNUstep binaries must be provided via the gnustep-core
# argument or by running gui/build-gui.sh outside Nix (see build/Makefile).
{ lib, stdenvNoCC, runCommand, src, themeDir, shellMenu, repoRoot ? null, gnustep-core ? null }:

runCommand "abzu-gui-core" {
  inherit themeDir shellMenu;
  meta.description = "GNUstep desktop core + AbzuAqua theme for the Abzu ISO";
} ''
  set -e
  mkdir -p "$out/Library/Themes" "$out/Library/Application Support/AbzuShell" \
           "$out/Applications" "$out/usr/local/share/gnustep"

  # Theme: ship the source tree as-is (ppm frames + theme-info.plist); the
  # GUI packager converts to .theme bundles at install time on first boot.
  cp -r ${themeDir} "$out/Library/Themes/AbzuAqua"
  cp ${shellMenu}   "$out/Library/Application Support/AbzuShell/shell-menu.json"

  # GNUstep itself: either nixpkgs-provided or built from pinned sources on
  # a Darwin builder via ../gui/build-gui.sh (stages gnustep-make→back→GWorkspace).
  #
  # FIX ("cannot coerce null to a string"): the previous version interpolated
  # the gnustep-core path unconditionally into this buildCommand string,
  # guarded only by a *runtime* shell test. Nix splices paths into the string
  # at *eval* time, so whenever gnustep-core was null (the default -- nothing
  # passes it), derivationStrict crashed while evaluating buildCommand of
  # abzu-gui-core, which propagated up through rootfs-intel to abzu-iso-intel.
  # The presence check must be done in Nix, via lib.optionalString, so the path
  # is only ever interpolated when the derivation actually exists.
  ${lib.optionalString (gnustep-core != null) ''
    cp -r ${gnustep-core}/. "$out/usr/local/share/gnustep/" || true
  ''}${lib.optionalString (gnustep-core == null) ''
    # No prebuilt GNUstep supplied: stage a STATUS marker only. We must NOT
    # invoke gui/build-gui.sh here — it derives its download cache from its own
    # file location, so running it from the read-only source store path tries
    # to mkdir gui/cache inside /nix/store and fails with "Permission denied".
    echo "GNUstep binaries require a Darwin builder (run gui/build-gui.sh outside Nix," > "$out/STATUS"
    echo "or pass gnustep-core to this derivation);"                                >> "$out/STATUS"
    echo "theme + shell menu are arch-independent and fully staged."                >> "$out/STATUS"
  ''}
''
