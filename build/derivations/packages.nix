# packages.nix — the "shelf": resolve packages/*/manifest.json into an
# install-on-demand catalogue shipped inside the ISO. Binaries are NOT baked
# in (license/provenance gating happens in ../../build/scripts/verify-packages.sh);
# first boot resolves entries against the vendored manifests.
{ lib, stdenvNoCC, runCommand, python3, manifests }:
let
  whisky = callPackage ./whisky.nix { };
  iina = callPackage ./iina.nix { };
  intel-sde = callPackage ./intel-sde.nix { };
  tor-browser = callPackage ./tor-browser.nix { };
  lm-studio = callPackage ./lm-studio.nix { };
  mole = callPackage ./mole.nix { };
  davit = callPackage ./davit.nix { };
  antinote = callPackage ./antinote.nix { };
  notproton = callPackage ./notproton.nix { };
in

runCommand "abzu-packages" {
  pathsToLink = [ "/usr/local/archives/manifests" ];
  nativeBuildInputs = [ python3 ];
  meta.description = "Abzu package shelf (emulators / history-archives / homelab manifests)";
} ''
  set -e
  # One tiny output per shelf so we can merge them via pathsToLink.
  ${lib.imap0 (i: m: ''
    d=$(mktemp -d); mkdir -p $d/usr/local/archives/manifests
    cp ${m} $d/usr/local/archives/manifests/shelf-${toString (i + 1)}-$(basename $(dirname ${m})).json
    cp -r $d/. $out/
  '') manifests ""}

  # Sanity: every staged manifest must parse and carry provenance fields —
  # mirrors scripts/verify-packages.sh so `nix flake check` catches drift.
  python3 - "$out" <<'PY'
import json, glob, sys
out = sys.argv[1]
req = ("name","version","source","license","provenance")
n = 0
for f in glob.glob(out + "/usr/local/archives/manifests/*.json"):
    d = json.load(open(f))
    for p in d.get("packages", []):
        missing = [k for k in req if k not in p]
        assert not missing, f"{f}:{p.get('name')} missing {missing}"
        n += 1
print(f"==> shelf: {n} packages across manifests, all verified")
PY
''
