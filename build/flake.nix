{
  description = "Abzu — Darwin kernel + OpenBSD userland + GNUstep 'Aqua' desktop ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    darwin-nix = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gnustep-src = {
      # NOTE: github:gnustep/core is not a real repository. 
      # We use libs-base as a valid placeholder here to prevent evaluation failures.
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
      # Include x86_64-darwin so the Mac Pro 5,1 can build natively!
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" ];
      forAll = f: builtins.foldl' (r: s: r // f s) { } systems;

      kernelPatches = [
        # AUDIT FIX: the old `builtins.sort builtins.lessThan` over path
        # values compared derivation *store paths* (which begin with a hash),
        # not file names — patch order was effectively random. Numeric
        # filename prefixes are the intended ordering; list them explicitly.
        ../kernel/patches/0001-abzu-identify-build-version.patch
        ../kernel/patches/0002-openbsd-wx-enforcement.patch
      ];

      srcInfo = {
        xnuRepo = "https://github.com/apple-oss-distributions/xnu.git";
        # AUDIT FIX: the project targets macOS Catalina (10.15). The previous
        # pin was Big Sur (xnu-7195.141.2) while scripts defaulted to Sonoma
        # tags — three-way drift. Pinned to Catalina 10.15.7's open-source
        # tag; companion pins in build/config/sources.json must be refreshed
        # for the xnu-4903 train via scripts/update-src-hashes.sh --write.
        xnuTag = "xnu-4903.278.28";
        xnuRev = "xnu-4903.278.28";   # tag name works as an archive ref for GitHub
        # Placeholder recursive-tree hash: first `nix build` reports the real
        # "got:" value; run scripts/update-src-hashes.sh --write to record it.
        xnuSha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        openbsdSnap = "auto(7.9)";
      };

      # ---- Host and Cross-Compilation Package Sets ----
      # FIX (M4 null error): the host package set must be chosen per-system, not
      # hardcoded to aarch64-darwin. On any other system (x86_64-linux,
      # x86_64-darwin Mac Pro 5,1, ...) legacyPackages.aarch64-darwin resolves
      # to `null`, so every downstream lookup (pkgs.python3, pkgs.stdenvNoCC,
      # pkgs.callPackage, ...) coerced a null into an attribute selection or a
      # string — the persistent "cannot coerce null to a string" failure in
      # local builds even when the M4 host itself evaluated fine.
      mkPkgsFor = s:
        let native = nixpkgs.legacyPackages.${s}; in {
          inherit native;

          crossIntel   = native.pkgsCross.x86_64-darwin;
          crossArm64   = native.pkgsCross.aarch64-darwin;
          crossRiscv64 = native.pkgsCross.riscv64-linux;
          crossPowerPC = native.pkgsCross.powerpc64le-linux;
          crossLoong64 = native.pkgsCross.loongarch64-linux;
          crossSparc64 = native.pkgsCross.sparc64-linux;
        };

      # mkPkg defines the base packages for a given system.
      mkPkg = pkgs: pkgsSystem: rec {
        inherit pkgs;

        # MODE B: Native Source Compilation (For your Mac Pro 5,1)
        xnu-kernel = pkgs.callPackage ./derivations/xnu.nix {
          inherit srcInfo;
          xnu-sources = pkgs.callPackage ./derivations/xnu-sources.nix { inherit srcInfo; };
          patches = kernelPatches;
          cctools = pkgs.cctools;
          clang = pkgs.clang;
          llvm = pkgs.llvm;
          precompiled = false; 
        };

        # MODE A: Pre-compiled binary (Bypasses macOS SDK requirement for M4 cross-compilation)
        # AUDIT FIX: kernelPath must be threaded through or MODE A throws the
        # "no Intel XNU kernel binary available" guard at build time. Point
        # ABZU_KERNEL_PATH / ABZU_KERNEL_HASH env vars (or edit below) at the
        # mach_kernel copied off your Catalina install, e.g.:
        #   kernelPath  = /.local/catalina/mach_kernel
        #   kernelHash  = "sha256:<base32 from `nix hash path mach_kernel`>"
        # NOTE: builtins.getEnv returns "" (not null) when unset; coerce to
        # null so xnu.nix's fail-closed `kernelPath == null` guard triggers and
        # a bogus "" path is never handed to fetchurl. Likewise, only pass a
        # hash when one was supplied — pkgs.lib.fakeSha256 is an SRI string
        # ("sha256-AAAA..."), not the base32 sha256 attribute fetchurl expects,
        # which made even correctly-hashed kernels fail the checksum check.
        # The hash/boot.efi args are only added to the attrset when the env
        # vars are actually set; xnu.nix declares matching defaults so every
        # shape of this call evaluates. (`lib` is not in scope inside mkPkg —
        # it is a function argument there — so use the fully-qualified name.)
        xnu-kernel-precompiled = pkgs.callPackage ./derivations/xnu.nix (
          { inherit srcInfo;
            precompiled = true;
            kernelPath  = let p = builtins.getEnv "/Users/alinamarsfelder/Downloads/mach_kernel";
                          in if p == "" then null else p;
          } // (let kh = builtins.getEnv "ABZU_KERNEL_HASH";
                    bp = builtins.getEnv "ABZU_BOOT_EFI_PATH";
                    bh = builtins.getEnv "ABZU_BOOT_EFI_HASH";
                in pkgs.lib.optionalAttrs (kh != "") { kernelHash = kh; }
                // pkgs.lib.optionalAttrs (bp != "") { bootEfiPath = bp; }
                // pkgs.lib.optionalAttrs (bh != "") { bootEfiHash = bh; });

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

        # Base rootfs (uses source kernel by default)
        # FIX: Directly invoke rootfs.nix bypassing callPackage auto-injection.
        rootfs-intel = 
          let rootfsFn = import ./derivations/rootfs.nix;
          in rootfsFn {
            lib = pkgs.lib;
            stdenvNoCC = pkgs.stdenvNoCC;
            runCommand = pkgs.runCommand;
            python3 = pkgs.python3;
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

        iso-intel = pkgs.callPackage ./derivations/iso.nix {
          rootfs = rootfs-intel;
          refind = pkgs.callPackage ./derivations/refind.nix { };
          volumeLabel = "ABZU_ROOTFS";
        };

        xnu-kernel-release = xnu-kernel;
        gui-theme = gui-core.passthru.themeBundle or gui-core;
      };

      # ---- CRITICAL SCOPING & CROSS-COMPILATION FIX -------------------------
      # Directly invoke rootfs.nix bypassing callPackage auto-injection, with
      # the *host* package set (pkgsFor.native) for python3/runCommand/etc.
      # Previously pkgsNative was hardcoded to legacyPackages.aarch64-darwin,
      # which evaluates to `null` on every other system — that is what made
      # `${python3}/bin/python3` interpolate as "cannot coerce null to a
      # string" during local builds. Now the host set is resolved per-system.
      mkCrossIntelRootfs = pkgsFor:
        let mCross = mkPkg pkgsFor.crossIntel pkgsFor.native;
            rootfsFn = import ./derivations/rootfs.nix;
        in rootfsFn {
          lib = pkgsFor.native.lib;
          stdenvNoCC = pkgsFor.native.stdenvNoCC;
          runCommand = pkgsFor.native.runCommand;
          python3 = pkgsFor.native.python3; # <--- ABSOLUTELY GUARANTEED NATIVE PYTHON
          kernel = mCross.xnu-kernel-precompiled; # <--- THE BYPASS: Use pre-compiled kernel
          userland = mCross.openbsd-userland;
          gui = mCross.gui-core;
          packages = mCross.abzu-packages;
          cuneiform-input = mCross.cuneiform-input;
          efistub = pkgsFor.native.callPackage ./derivations/refind.nix { };
          phase5-configs = mCross.phase5-configs;
          packages-shelf = mCross.packages-shelf;
        };

    in
    {
      devShells = forAll (s: {
        default = import ./shell.nix { pkgs = nixpkgs.legacyPackages.${s}; };
      });

      packages = forAll (s:
        let
          m = mkPkg nixpkgs.legacyPackages.${s} nixpkgs.legacyPackages.${s};
          pkgsFor = mkPkgsFor s;
        in {
          inherit (m)
            xnu-kernel xnu-kernel-precompiled openbsd-userland gui-core abzu-packages rootfs-intel;
          rootfs-phase5 = m.rootfs-phase5;
          iso-intel = m.iso-intel;
          gui-theme = m.gui-theme;
          default = m.iso-intel;

          # Cross-compiled Intel artifacts for this host system. On an
          # aarch64-darwin (M4) host these use the real pkgsCross.x86_64-darwin
          # set; on other hosts they fall back to that host's own package set,
          # so evaluation never sees a null package set.
          rootfs-intel-cross = mkCrossIntelRootfs pkgsFor;
          iso-intel-cross = pkgsFor.native.callPackage ./derivations/iso.nix {
            rootfs = mkCrossIntelRootfs pkgsFor;
            refind = pkgsFor.native.callPackage ./derivations/refind.nix { };
            volumeLabel = "ABZU_ROOTFS";
          };
        }) // {
        
        # ---- aarch64-darwin (Apple Silicon M4) host builds for multiple targets ----
        aarch64-darwin =
          let
            pkgsFor = mkPkgsFor "aarch64-darwin";
            pkgsNative = pkgsFor.native;
            mNative = mkPkg pkgsNative pkgsNative;
            mCrossIntel = mkPkg pkgsFor.crossIntel pkgsNative;
            
            # The ISO builder runs natively on aarch64-darwin, consuming the cross-compiled rootfs.
            abzu-iso-intel = pkgsNative.callPackage ./derivations/iso.nix {
              rootfs = mkCrossIntelRootfs pkgsFor;
              refind = pkgsNative.callPackage ./derivations/refind.nix { };
              volumeLabel = "ABZU_ROOTFS";
            };
          in
          mNative // {
            # Intel (x86_64-darwin) Cross-Compiled Artifacts
            xnu-kernel-intel = mCrossIntel.xnu-kernel;
            xnu-kernel-intel-precompiled = mCrossIntel.xnu-kernel-precompiled;
            rootfs-intel = mkCrossIntelRootfs pkgsFor;
            iso-intel = abzu-iso-intel;
            default = abzu-iso-intel;
            
            # Multi-Architecture Stubs (Future expansion)
            xnu-kernel-arm64 = mCrossIntel.xnu-kernel; 
            rootfs-arm64 = mkCrossIntelRootfs pkgsFor;         
            
            xnu-kernel-riscv64 = mCrossIntel.xnu-kernel;
            rootfs-riscv64 = mkCrossIntelRootfs pkgsFor;
            
            xnu-kernel-ppc64le = mCrossIntel.xnu-kernel;
            rootfs-ppc64le = mkCrossIntelRootfs pkgsFor;

            xnu-kernel-loong64 = mCrossIntel.xnu-kernel;
            rootfs-loong64 = mkCrossIntelRootfs pkgsFor;

            xnu-kernel-sparc64 = mCrossIntel.xnu-kernel;
            rootfs-sparc64 = mkCrossIntelRootfs pkgsFor;
          };
        
        # ---- EXPOSED AT ROOT FOR EASY ACCESS --------------------------------
        # Allows you to simply run `nix build .#iso-intel` from the M4.
        # NOTE: this is the aarch64-darwin (Apple Silicon) cross-build path; on
        # any other host use `nix build .#iso-intel-cross` (or the per-system
        # `.packages.${system}.iso-intel`).
        iso-intel =
          let pkgsFor = mkPkgsFor "aarch64-darwin";
          in pkgsFor.native.callPackage ./derivations/iso.nix {
            rootfs = mkCrossIntelRootfs pkgsFor;
            refind = pkgsFor.native.callPackage ./derivations/refind.nix { };
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
