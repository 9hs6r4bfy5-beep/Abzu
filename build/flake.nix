{
  description = "Abzu — Darwin kernel + OpenBSD userland + GNUstep 'Aqua' desktop ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    darwin-nix = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gnustep-src = {
      # NOTE (audit 2026-10-10): github:gnustep/core is NOT a real repository.
      # Upstream lives at git.savannah.gnu.org/gnustep. We use libs-base as a 
      # valid placeholder here to prevent evaluation failures. You should wire 
      # gui-core to the verified tarballs in build/config/distfiles.sha256.
      url = "github:gnustep/libs-base/master";
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

      kernelPatches = builtins.sort builtins.lessThan ([
        ../kernel/patches/0001-abzu-identify-build-version.patch
        ../kernel/patches/0002-openbsd-wx-enforcement.patch
      ]);

      srcInfo = {
        xnuRepo = "https://github.com/apple-oss-distributions/xnu.git";
        xnuTag = "xnu-7195.141.2";
        xnuRev = "776661b72c2db9861865df68d309f6f35faccff4";
        xnuSha256 = "sha256-NH/s8/t4oOq6bVhRXlslX7lZFWV4E00yTPxyY7A7KE0=";
        openbsdSnap = "auto(7.9)";
      };

      # ---- Host and Cross-Compilation Package Sets ----
      pkgsNative = nixpkgs.legacyPackages.aarch64-darwin;
      
      pkgsCrossIntel   = pkgsNative.pkgsCross.x86_64-darwin;
      pkgsCrossArm64   = pkgsNative.pkgsCross.aarch64-darwin;
      pkgsCrossRiscv64 = pkgsNative.pkgsCross.riscv64-linux;
      pkgsCrossPowerPC = pkgsNative.pkgsCross.powerpc64le-linux;
      pkgsCrossLoong64 = pkgsNative.pkgsCross.loongarch64-linux;
      pkgsCrossSparc64 = pkgsNative.pkgsCross.sparc64-linux;

      mkPkg = pkgs: pkgsSystem: rec {
        inherit pkgs;

        xnu-kernel = pkgs.callPackage ./derivations/xnu.nix {
          inherit srcInfo;
          xnu-sources = pkgs.callPackage ./derivations/xnu-sources.nix { inherit srcInfo; };
          patches = kernelPatches;
          cctools = pkgs.cctools;
          clang = pkgs.clang;
          llvm = pkgs.llvm;
        };

        openbsd-userland = pkgs.callPackage ./derivations/openbsd-userland.nix {
          inherit srcInfo;
          manifest = ../userland/import/tools.manifest;
          skipList = ../userland/import/skip.txt;
          compatSrc = ../userland/mach_compat/abzu-compat.c;
          etcOverlay = ../userland/etc;
          repoRoot = ../.;
        };

        gui-core = pkgs.callPackage ./derivations/gnustep.nix {
          src = gnustep-src;
          themeDir = ../gui/themes/abzu-aqua;
          shellMenu = ../gui/gworkspace-shell/shell-menu.json;
          repoRoot = ../.;
        };

        abzu-packages = pkgs.callPackage ./derivations/packages.nix {
          manifests = [
            ../packages/gaming/manifest.json
            ../packages/history-archives/manifest.json
            ../packages/homelab/manifest.json
          ];
        };

        cuneiform-input = pkgs.callPackage ./derivations/cuneiform-input.nix { };

        phase5-configs = pkgs.runCommand "abzu-phase5-configs" { } ''
          mkdir -p $out
          cp -r --no-preserve=ownership ${../packages/homelab/etc-skel} $out/etc-skel
          cp -r --no-preserve=ownership ${../packages/history-archives/stellarium-defaults} $out/stellarium-defaults
        '';

        packages-shelf = ../packages;

        rootfs-intel = pkgs.callPackage ./derivations/rootfs.nix {
          kernel = xnu-kernel;
          userland = openbsd-userland;
          gui = gui-core;
          packages = abzu-packages;
          cuneiform-input = cuneiform-input;
          efistub = pkgs.callPackage ./derivations/refind.nix { };
          inherit phase5-configs packages-shelf;
        };

        rootfs-phase5 = pkgs.callPackage ./derivations/rootfs-slim.nix {
          inherit xnu-kernel openbsd-userland gui-core cuneiform-input
                  phase5-configs packages-shelf;
        };

        # Template ISO (overridden below for cross-compilation)
        iso-intel = pkgs.callPackage ./derivations/iso.nix {
          rootfs = rootfs-intel;
          refind = pkgs.callPackage ./derivations/refind.nix { };
          volumeLabel = "ABZU_ROOTFS";
        };

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
          rootfs-phase5 = m.rootfs-phase5;
          iso-intel = m.iso-intel;
          gui-theme = m.gui-theme;
          default = m.iso-intel;
        }) // {
        
        # ---- aarch64-darwin (Apple Silicon) host builds for multiple targets ----
        aarch64-darwin =
          let
            mNative = mkPkg pkgsNative pkgsNative;
            
            mCrossIntel   = mkPkg pkgsCrossIntel   pkgsNative;
            mCrossArm64   = mkPkg pkgsCrossArm64   pkgsNative;
            mCrossRiscv64 = mkPkg pkgsCrossRiscv64 pkgsNative;
            mCrossPowerPC = mkPkg pkgsCrossPowerPC pkgsNative;
            mCrossLoong64 = mkPkg pkgsCrossLoong64 pkgsNative;
            mCrossSparc64 = mkPkg pkgsCrossSparc64 pkgsNative;

            # CRITICAL: Define the ISO derivation in the let block to guarantee 
            # it is in scope for both 'iso-intel' and 'default' attributes below.
            abzu-iso-intel = pkgsNative.callPackage ./derivations/iso.nix {
              rootfs = mCrossIntel.rootfs-intel;
              refind = pkgsNative.callPackage ./derivations/refind.nix { };
              volumeLabel = "ABZU_ROOTFS";
            };
          in
          mNative // {
            # Intel (x86_64-darwin)
            xnu-kernel-intel = mCrossIntel.xnu-kernel;
            rootfs-intel     = mCrossIntel.rootfs-intel;
            iso-intel        = abzu-iso-intel;
            default          = abzu-iso-intel;
            
            # Apple Silicon (aarch64-darwin)
            xnu-kernel-arm64 = mCrossArm64.xnu-kernel;
            rootfs-arm64     = mCrossArm64.rootfs-intel;
            
            # RISC-V (riscv64-linux)
            xnu-kernel-riscv64 = mCrossRiscv64.xnu-kernel;
            rootfs-riscv64     = mCrossRiscv64.rootfs-intel;
            
            # PowerPC (powerpc64le-linux)
            xnu-kernel-ppc64le = mCrossPowerPC.xnu-kernel;
            rootfs-ppc64le     = mCrossPowerPC.rootfs-intel;

            # LoongArch (loongarch64-linux)
            xnu-kernel-loong64 = mCrossLoong64.xnu-kernel;
            rootfs-loong64     = mCrossLoong64.rootfs-intel;

            # SPARC (sparc64-linux)
            xnu-kernel-sparc64 = mCrossSparc64.xnu-kernel;
            rootfs-sparc64     = mCrossSparc64.rootfs-intel;
          };
        
        # ---- EXPOSED AT ROOT FOR EASY ACCESS --------------------------------
        iso-intel = 
          let mCrossIntel = mkPkg pkgsCrossIntel pkgsNative; 
          in pkgsNative.callPackage ./derivations/iso.nix {
               rootfs = mCrossIntel.rootfs-intel;
               refind = pkgsNative.callPackage ./derivations/refind.nix { };
               volumeLabel = "ABZU_ROOTFS";
             };
      };

      checks = forAll (s: {
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
