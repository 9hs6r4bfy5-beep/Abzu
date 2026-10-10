{
  description = "Abzu — Darwin kernel + OpenBSD userland + GNUstep 'Aqua' desktop ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # Corrected nix-darwin input (uses the official repo and tracks master)
    darwin-nix = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gnustep-src = {
      url = "github:gnustep/core/master";
      flake = false;
    };
  };

  outputs =
    { self
    , nixpkgs
    , darwin-nix
    , gnustep-src
    }@inputs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: builtins.foldl' (r: s: r // f s) { } systems;

      # Single source of truth for the Abzu XNU patch set. Nix has no glob,
      # so we pin the list explicitly; `nix flake check` fails loudly if a
      # file is added/renamed here without updating this list (and vice
      # versa via the patches-present check below). xnu.nix applies them in
      # sorted order with `patchFlags = [ "-p1" ]` (git-style a/ b/ prefixes;
      # matches kernel/build-xnu.sh's plain `git apply`).
      kernelPatches = builtins.sort builtins.lessThan ([
        ../kernel/patches/0001-abzu-identify-build-version.patch
        ../kernel/patches/0002-openbsd-wx-enforcement.patch
      ]);

      # Single source of truth for upstream pins. xnuRev/xnuSha256 are filled
      # by build/scripts/update-src-hashes.sh (tag → immutable commit + SRI).
      srcInfo = {
        xnuRepo = "https://github.com/apple-oss-distributions/xnu.git";
        xnuTag = "xnu-7195.141.2";                       # macOS 11.3 Big Sur OSS drop
        xnuRev = "776661b72c2db9861865df68d309f6f35faccff4";  # commit tagged xnu-7195.141.2
        xnuSha256 = "sha256-NH/s8/t4oOq6bVhRXlslX7lZFWV4E00yTPxyY7A7KE0="; # GitHub archive tarball of xnuRev
        openbsdSnap = "7.6";
      };

      mkPkg = pkgs: pkgsSystem: rec {
        inherit pkgs;

        # ---- kernel -------------------------------------------------------
        xnu-kernel = pkgs.callPackage ./derivations/xnu.nix {
          inherit srcInfo;
          pkgsHost = pkgsSystem;
          xnu-sources = pkgs.callPackage ./derivations/xnu-sources.nix { inherit srcInfo; };
          patches = kernelPatches;   # explicit sorted file list (see let-block)
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
            ../packages/gaming/manifest.json
            ../packages/history-archives/manifest.json
            ../packages/homelab/manifest.json
          ];
        };

        # ---- cuneiform input method --------------------------------------
        cuneiform-input = pkgs.callPackage ./derivations/cuneiform-input.nix { };

        # ---- Phase 5 use-case optimization defaults ------------------------
        phase5-configs = pkgs.runCommand "abzu-phase5-configs" { } ''
          mkdir -p $out
          cp -r --no-preserve=ownership ${../packages/homelab/etc-skel} $out/etc-skel
          cp -r --no-preserve=ownership ${../packages/history-archives/stellarium-defaults} $out/stellarium-defaults
        '';

        # the shelf source tree (gaming/quiver-defaults.json et al.) as a data dep
        packages-shelf = ../packages;

        # ---- rootfs + ISO --------------------------------------------------
        rootfs-intel = pkgs.callPackage ./derivations/rootfs.nix {
          kernel = xnu-kernel;
          userland = openbsd-userland;
          gui = gui-core;
          packages = abzu-packages;
          cuneiform-input = cuneiform-input;
          efistub = pkgs.callPackage ./derivations/refind.nix { };
          inherit phase5-configs packages-shelf;
        };

        # ---- slim Phase 5 rootfs (abzu-rootfs variant) ----------------------
        # The slim "abzu-rootfs" derivation lives in its own module
        # ./rootfs-slim.nix because callPackage can only reach a file's
        # first top-level export (rootfs.nix exports abzu-rootfs-intel).
        rootfs-phase5 = pkgs.callPackage ./derivations/rootfs-slim.nix {
          inherit xnu-kernel openbsd-userland gui-core cuneiform-input
                  phase5-configs packages-shelf;
        };

        iso-intel = pkgs.callPackage ./derivations/iso.nix {
          rootfs = rootfs-intel;
          refind = pkgs.callPackage ./derivations/refind.nix { };
          # Unified label — derivations/iso.nix and refind.conf must agree.
          volumeLabel = "ABZU_ROOTFS";
        };

        # convenience aliases
        xnu-kernel-release = xnu-kernel;
        gui-theme = gui-core.passthru.themeBundle or gui-core;
      };
    in
    {
      devShells = forAll (s: {
        default = import ./shell.nix { pkgs = nixpkgs.legacyPackages.${s}; };
      });

      packages = forAll (s:
        let m = mkPkg nixpkgs.legacyPackages.${s} nixpkgs.legacyPackages.${s};
        in {
          inherit (m)
            xnu-kernel openbsd-userland gui-core abzu-packages rootfs-intel;
          rootfs-phase5 = m.rootfs-phase5;   # slim Phase 5 "abzu-rootfs"
          iso-intel = m.iso-intel;
          gui-theme = m.gui-theme;
          default = m.iso-intel;
        }) // {
        # ---- aarch64-darwin (Apple Silicon) host ----------------------------
        # NOTE: we deliberately do NOT expose an aarch64-darwin package set
        # here. The old version referenced pkgsNative.cctools, which no
        # longer exists in nixpkgs (the Darwin CCTools port was removed), so
        # *evaluating* this attrset on any Linux machine failed outright —
        # even `nix flake check`. XNU is only buildable on a Darwin host via
        # the Makefile pipeline (kernel/build-xnu.sh); see README. When an
        # Apple Silicon builder is wired up, re-add it behind
        # `if builtins.currentSystem == "aarch64-darwin" then ... else { }`
        # with a real clang/cctools-compatible stdenv.
      };

      checks = forAll (s: {
        # Only *manifest* JSON is validated here; other *.json files in the
        # shelf (e.g. gaming/quiver-defaults.json) are app defaults with a
        # different schema and must not be subjected to the manifest keys.
        manifests-valid = nixpkgs.legacyPackages.${s}.runCommand "check-manifests" { } ''
          ${nixpkgs.legacyPackages.${s}.python3}/bin/python3 - <<'PY'
import json,glob,sys
ok=True
for f in glob.glob("${../packages}/*/manifest.json"):
    d=json.load(open(f))
    for p in d["packages"]:
        for k in ("name","version","source","license","provenance"):
            if k not in p: print("MISSING",k,"in",f,p.get("name")); ok=False
sys.exit(0 if ok else 1)
PY
          touch $out
        '';

        # Guard the explicit kernelPatches list against drift: every file
        # that exists in ../kernel/patches must be listed above (and every
        # listed path must exist — Nix would have failed evaluation already).
        patches-listed = nixpkgs.legacyPackages.${s}.runCommand "check-patches-listed" { } ''
          ${nixpkgs.legacyPackages.${s}.bash}/bin/bash -eu -o pipefail <<'SH'
          shopt -s nullglob
          listed=${builtins.toString (map (p: builtins.baseNameOf p) kernelPatches)}
          for f in ${../kernel/patches}/*.patch; do
            b=$(basename "$f")
            case " $listed " in *" $b "*) ;; *)
              echo "kernel patch not in flake kernelPatches list: $b"; exit 1;;
            esac
          done
          SH
          touch $out
        '';
      });
    };
}
