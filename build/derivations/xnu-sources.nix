# xnu-sources.nix — fetch Apple's open-source XNU (macOS 11.3 Big Sur,
# xnu-7195.141.2) plus the APSL companion projects XNU's Makefile expects as
# sibling directories (mach, libkern, IOKitUser, ...).
#
# Fetching is *declarative*: every URL is pinned to a commit SHA and hashed,
# so `nix build .#xnu-kernel` never touches the network implicitly and cannot
# silently drift onto different sources.
#
# The result is a single source tree laid out the way Apple's own build
# expects:
#   <src>/xnu/                       ← XNU itself (patches applied here)
#   <src>/mach/  <src>/libkern/  <src>/IOKitUser/ ...   ← siblings
#
# Companion pins live in ../config/sources.json so they can be refreshed with
# scripts/update-src-hashes.sh without touching Nix syntax.
{ stdenvNoCC, fetchzip, git, runCommand, srcInfo }:

let
  companions = builtins.fromJSON (builtins.readFile ../config/sources.json);

in runCommand "abzu-xnu-sources-${srcInfo.xnuTag}" {
  nativeBuildInputs = [ git ];
  meta.description = "XNU ${srcInfo.xnuTag} + APSL companion sources, assembled for in-tree builds";
} ''
  mkdir -p $out
  cp -r --preserve=mode,timestamps ${fetchzip {
    url = "github:apple-oss-distributions/xnu/archive/${srcInfo.xnuRev}.tar.gz";
    hash = srcInfo.xnuSha256;
    stripRoot = true;
  }} $out/xnu
  chmod -R u+w $out
  ${builtins.concatStringsSep "\n"
    (builtins.mapAttrs (name: spec: ''
      cp -r ${fetchzip {
        url = "github:apple-oss-distributions/${name}/archive/${spec.rev}.tar.gz";
        hash = spec.sha256;
        stripRoot = true;
      }} $out/${name}
    '') (builtins.removeAttrs companions [ "_comment" ]))}
  # Give the tree a git identity so `git apply --check` works even though
  # fetchzip strips .git.
  cd $out/xnu && git init -q && git add -A >/dev/null 2>&1 && \
    git -c user.email=abzu@build -c user.name=abzu commit -qm "xnu ${srcInfo.xnuTag}" || true
''
