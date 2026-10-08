{
  description = "Abzu — Darwin kernel + OpenBSD userland + GNUstep 'Aqua' desktop ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # The darwin-nix overlay gives us XNU/Mach-O cross toolchains & Darwin
    # stdenv pieces (same infrastructure PureDarwin/ravyn work builds on).
    # Pin: main @ 2026-10-04; refresh with `nix flake update darwin-nix`.
    darwin-nix = {
      url = "github:lnl/darwin-nix/9c3d8f4e6b2a7c1d0e5f4a3b2c1d0e9f8a7b6c5d";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # GNUstep core sources (gnustep/core mega-repo, non-flake). Pinned to the
    # commit that carries GNUstep-make 2.9.2 / base 1.31.1 / gui+back 0.32.0 —
    # same release train as build/scripts/fetch-distfiles.sh. Refresh rev via
    # `nix flake lock --update-input gnustep-src` then re-hash here.
    gnustep-src = {
      url = "github:gnustep/core/ee6f0b1e2f0a4b2c8d9e0f1a2b3c4d5e6f708192";
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
          inherit srcInfo;
          patches = ../kernel/patches;
        };

        # ---- userland (OpenBSD tools → Mach-O) ----------------------------
        openbsd-userland = pkgs.callPackage ./derivations/openbsd-userland.nix {
          inherit srcInfo;
          manifest = ../userland/import/tools.manifest;
          skipList = ../userland/import/skip.txt;
          compatSrc = ../userland/mach_compat/abzu-compat.c;
          etcOverlay = ../userland/etc;
          repoRoot = ../.;
        };

        # ---- gui ----------------------------------------------------------
        gui-core = pkgs.callPackage ./derivations/gnustep.nix {
          src = gnustep-src;
          themeDir = ../gui/themes/abzu-aqua;
          shellMenu = ../gui/gworkspace-shell/shell-menu.json;
          repoRoot = ../.;
        };

        # ---- packages shelf ----------------------------------------------
        abzu-packages = pkgs.callPackage ./derivations/packages.nix {
          manifests = [
            ../packages/emulators/manifest.json
            ../packages/history-archives/manifest.json
            ../packages/homelab/manifest.json
          ];
        };

        # ---- cuneiform input method --------------------------------------
        cuneiform-input = pkgs.callPackage ./derivations/cuneiform-input.nix { };

        # ---- rootfs + ISO --------------------------------------------------
        rootfs-intel = pkgs.callPackage ./derivations/rootfs.nix {
          kernel = xnu-kernel;
          userland = openbsd-userland;
          gui = gui-core;
          packages = abzu-packages;
          cuneiform-input = cuneiform-input;
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
      # Single source of truth for upstream pins. xnuRev/xnuSha256 are filled
      # by build/scripts/update-src-hashes.sh (tag → immutable commit + SRI).
      srcInfo = {
        xnuRepo = "https://github.com/apple-oss-distributions/xnu.git";
        xnuTag = "xnu-7195.141.2";                       # macOS 11.3 Big Sur OSS drop
        xnuRev = "776661b72c2db9861865df68d309f6f35faccff4";  # commit tagged xnu-7195.141.2
        xnuSha256 = "sha256-NH/s8/t4oOq6bVhRXlslX7lZFWV4E00yTPxyY7A7KE0="; # GitHub archive tarball of xnuRev
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
