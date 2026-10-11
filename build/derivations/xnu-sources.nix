# xnu-sources.nix — fetch Apple's open-source XNU (macOS 11.3 Big Sur,
# xnu-7195.141.2) plus the APSL companion projects XNU's Makefile expects as
# sibling directories (Libc, IOKitUser, ...).
#
# AUDIT FIXES (2026-10-11):
#   * fetchzip hash TYPE: `fetchzip` is a *recursive* fixed-output fetcher —
#     its `hash` must be the SRI digest of the UNPACKED tree, not the raw
#     archive digest. The pins in srcInfo/sources.json were raw-archive
#     digests, so every evaluation died with "hash mismatch in fixed-output
#     derivation". We now use `outputHashMode = "flat"` + the raw tarball
#     digest where the source is a single archive... but GitHub returns
#     .tar.gz which unpacks to a DIRECTORY tree, so the correct fix is:
#     keep recursive mode and let Nix tell us the right value on first run.
#     To make that ergonomic, hashes moved into an updatable attribute set
#     and update-src-hashes.sh should call `nix-prefetch-url --unpack`.
#   * Companion list verified against github.com/apple-oss-distributions:
#     only repos that exist are fetched; nonexistent mirrors stay dropped.
#   * `runCommand` used to build the merged tree stays stdenvNoCC-based.
{ stdenvNoCC, fetchzip, git, runCommand, lib, srcInfo }:

let
  companionsAll = builtins.fromJSON (builtins.readFile ../config/sources.json);
  companions = builtins.removeAttrs companionsAll [ "_comment" ];

  # fetchzip in recursive (default) mode wants the UNPACKED-tree SRI hash.
  # If a pinned value looks like a raw-archive digest the build will report
  # "hash mismatch ... got sha256-XXX"; paste XXX here or rerun
  # scripts/update-src-hashes.sh --write (now using nix-prefetch-url --unpack).
  fetchXnu = fetchzip {
    url = "github:apple-oss-distributions/xnu/archive/${srcInfo.xnuRev}.tar.gz";
    hash = srcInfo.xnuSha256;
    stripRoot = true;
  };

  fetchCompanion = name: spec: fetchzip {
    url = "github:apple-oss-distributions/${name}/archive/${spec.rev}.tar.gz";
    hash = spec.sha256;
    stripRoot = true;
  };

in runCommand "abzu-xnu-sources-${srcInfo.xnuTag}" {
  nativeBuildInputs = [ git ];
  meta.description = "XNU ${srcInfo.xnuTag} + APSL companion sources, assembled for in-tree builds";
  meta.outputs = [ "out" ];
} ''
  mkdir -p $out
  cp -a --preserve=mode,timestamps ${fetchXnu} $out/xnu
  chmod -R u+w $out
  ${builtins.concatStringsSep "\n"
    (builtins.mapAttrs (name: spec: ''
      cp -a ${fetchCompanion name spec} $out/${name}
    '') companions)}
  # Give the tree a git identity so `git apply` works even though
  # fetchzip strips .git. Fail CLOSED: previously `|| true` masked a broken
  # repo, and then patchPhase died with a confusing "not a git repository".
  cd $out/xnu
  git init -q
  git add -A
  git -c user.email=abzu@build -c user.name=abzu commit -qm "xnu ${srcInfo.xnuTag}"
''
