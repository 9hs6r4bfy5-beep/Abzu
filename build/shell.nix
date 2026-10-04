# shell.nix — dev shell for the Abzu build environment ({ pkgs }: ...)
{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  name = "abzu-build";
  packages = with pkgs; [
    nix-prefetch-scripts
    git gnupg cacert
    curl python3
    xorriso genisoimage dosfstools mtools isoinfo
    cpio unzip xz zstd
    gnutar
  ];
  shellHook = ''
    echo "Abzu build env — see build/README.md"
    echo "  nix flake check                    # eval-only validation (works on Linux)"
    echo "  nix build .#xnu-kernel             # needs Darwin builder / container path"
    echo "  nix build .#iso-intel              # bootable hybrid ISO (installer-skeleton w/o kernel)"
    echo "  ./scripts/update-src-hashes.sh     # refresh source pins + hashes"
  '';
}
