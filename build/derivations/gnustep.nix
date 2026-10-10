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
  if [ -n "${if gnustep-core != null then "yes" else ""}" ]; then
    cp -r ${gnustep-core}/. "$out/usr/local/share/gnustep/" || true
  elif [ "$(uname -s)" = "Darwin" ]; then
    STAGE="$out" ${repoRoot}/gui/build-gui.sh || exit 1
  else
    echo "GNUstep binaries require a Darwin builder (see gui/build-gui.sh);" > "$out/STATUS"
    echo "theme + shell menu are arch-independent and fully staged."       >> "$out/STATUS"
  fi
''
