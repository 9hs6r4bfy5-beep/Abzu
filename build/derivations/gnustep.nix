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
{ lib, stdenvNoCC, runCommand, src, themeDir, shellMenu, repoRoot, gnustep-core ? null }:

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
    if [ "$(uname -s)" = "Darwin" ]; then
      STAGE="$out" ${repoRoot}/gui/build-gui.sh || exit 1
    else
      echo "GNUstep binaries require a Darwin builder (see gui/build-gui.sh);" > "$out/STATUS"
      echo "theme + shell menu are arch-independent and fully staged."       >> "$out/STATUS"
    fi
  ''}
''
