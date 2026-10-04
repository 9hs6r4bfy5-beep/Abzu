{
  description = "Abzu — Darwin kernel + OpenBSD userland + GNUstep 'Aqua' desktop ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # The darwin-nix overlay gives us XNU/Mach-O cross toolchains & Darwin
    # stdenv pieces (same infrastructure PureDarwin/ravyn work builds on).
    darwin-nix = {
      url = "github:lnl/darwin-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gnustep-src = {
      url = "github:gnustep/gnustep-core-sources";   # placeholder mirror; see gui/gnustep-overlay pins
      flake = false;
    };
  };

  outputs =
    { self
    , nixpkgs
    , darwin-nix
    , gnustep-src
    }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: builtins.foldl' (r: s: r // f s) { } systems;
      mkPkg = pkgs: rec {
        inherit pkgs;

        # ---- kernel -------------------------------------------------------
        xnu-kernel = pkgs.callPackage ./derivations/xnu.nix {
          inherit (self) srcInfo;
          patches = ../kernel/patches;
        };

        # ---- userland (OpenBSD tools → Mach-O) ----------------------------
        openbsd-userland = pkgs.callPackage ./derivations/openbsd-userland.nix {
          manifest = ../userland/import/tools.manifest;
          skipList = ../userland/import/skip.txt;
          compatSrc = ../userland/mach_compat/abzu-compat.c;
          etcOverlay = ../userland/etc;
        };

        # ---- gui ----------------------------------------------------------
        gui-core = pkgs.callPackage ./derivations/gnustep.nix {
          src = gnustep-src;
          themeDir = ../gui/themes/abzu-aqua;
          shellMenu = ../gui/gworkspace-shell/shell-menu.json;
        };

        # ---- packages shelf ----------------------------------------------
        abzu-packages = pkgs.callPackage ./derivations/packages.nix {
          manifests = [
            ../packages/emulators/manifest.json
            ../packages/history-archives/manifest.json
            ../packages/homelab/manifest.json
          ];
        };

        # ---- rootfs + ISO --------------------------------------------------
        rootfs-intel = pkgs.callPackage ./derivations/rootfs.nix {
          kernel = xnu-kernel;
          userland = openbsd-userland;
          gui = gui-core;
          packages = abzu-packages;
          efistub = pkgs.callPackage ./derivations/refind.nix { };
        };

        iso-intel = pkgs.callPackage ./derivations/iso.nix {
          rootfs = rootfs-intel;
          volumeLabel = "ABZU_ABYS SOLITH";   # split below at build time
        };

        # convenience aliases
        xnu-kernel-release = xnu-kernel;
        gui-theme = gui-core.passthru.themeBundle or gui-core;
      };
    in
    {
      srcInfo = {
        xnuRepo = "https://github.com/apple-oss-distributions/xnu.git";
        xnuTag = "xnu-11417.101.15";
        openbsdSnap = "7.6";
      };

      devShells = forAll (s: {
        default = import ./shell.nix { pkgs = nixpkgs.legacyPackages.${s}; };
      });

      packages = forAll (s:
        let m = mkPkg nixpkgs.legacyPackages.${s};
        in {
          inherit (m)
            xnu-kernel openbsd-userland gui-core abzu-packages rootfs-intel;
          iso-intel = m.iso-intel;
          gui-theme = m.gui-theme;
          default = m.iso-intel;
        });

      checks = forAll (s: {
        manifests-valid = nixpkgs.legacyPackages.${s}.runCommand "check-manifests" { } ''
          ${nixpkgs.legacyPackages.${s}.python3}/bin/python3 - <<'PY'
import json,glob,sys
ok=True
for f in glob.glob("${../packages}/*/*.json"):
    d=json.load(open(f))
    for p in d["packages"]:
        for k in ("name","version","source","license","provenance"):
            if k not in p: print("MISSING",k,"in",f,p.get("name")); ok=False
sys.exit(0 if ok else 1)
PY
          touch $out
        '';
      });
    };
}
