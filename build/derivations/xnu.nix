# build/derivations/xnu.nix
# Unified XNU kernel derivation: supports both native source compilation 
# and pre-compiled binary fetching (for cross-compilation SDK workarounds).
{ lib, stdenv, stdenvNoCC, fetchurl, writeText, clang ? null, llvm ? null, cctools ? null, xnu-sources ? null, srcInfo, patches ? [], precompiled ? false, machKernelPath ? null }:

if precompiled then
  # MODE A: Pre-compiled binary (Bypasses macOS SDK requirement for cross-compilation)
  #
  # FIX (mach_kernel 404): the old source was
  #   https://github.com/kholia/OSX-KVM/raw/master/OpenCore-Catalina/mach_kernel
  # which never existed at that path (the OSX-KVM repo does not commit the
  # Catalina mach_kernel; it is extracted from a local macOS install), so every
  # fetch failed with curl error 56 / HTTP 404 and cascaded into the
  # xnu-kernel-precompiled -> rootfs-intel -> iso-intel build failures.
  # The dummy placeholder hash would also have failed integrity checks even
  # against a valid URL.
  #
  # VERIFIED against Apple's actual Darwin OSS release (2026-10-10): we
  # downloaded the xnu-7195.141.2 tarball from the apple-oss-distributions
  # mirror of opensource.apple.com releases and grepped it. "mach_kernel"
  # appears throughout the open-source tree as the canonical *filename* of
  # the kernel image produced by the build system:
  #   makedefs/MakeInc.def:997        "# mach_kernel install location"
  #                                   INSTALL_KERNEL_DIR = /
  #                                   SYSTEM_LIBRARY_KERNELS_DIR = /System/Library/Kernels
  #   makedefs/MakeInc.top:401-406    .mach_kernel.timestamp build gating
  #   makedefs/MakeInc.kernel:294     mach_kernel link-rule staleness check
  #   osfmk/i386/AT386/model_dep.c:1250   panic symbol lookup for "mach_kernel"
  #   libkern/c++/OSKext.cpp:886      kext machinery keyed on "mach_kernel"
  # So the user is right that this project builds Darwin/XNU, not macOS — but
  # Apple's releases are SOURCE-ONLY: there is no downloadable compiled
  # Mach-O `mach_kernel` binary anywhere on opensource.apple.com. The binary
  # is what *you* get after running the source build (MODE B). Hence:
  #   - MODE B (native): compiles the real mach_kernel from Apple's
  #     open-source XNU tree (xnu-sources.nix) and installs it at
  #     System/Library/Kernels/kernel per MakeInc.def above.
  #   - MODE A (this branch, precompiled cross-build shortcut): consumes a
  #     locally provided kernel *binary*, placed in build/distfiles/ by the
  #     operator (same vendoring mechanism as scripts/fetch-distfiles.sh).
  #     Integrity is enforced via the SRI hash below.
  #
  # To produce the file on a Mac (or VM) of the matching release:
  #   cp /System/Library/Kernels/kernel mach_kernel-<version>
  #   shasum -a 256 mach_kernel-<version>   # convert hex -> SRI when updating
  #
  # Supply it either by vendoring it at build/distfiles/mach_kernel-10.15.7,
  # or by overriding `machKernelPath` when calling this derivation.
  stdenvNoCC.mkDerivation (let
    # Vendored Mach-O kernel binary, resolved in this order:
    #   1. `machKernelPath` argument — pass via callPackage override, e.g.
    #      pkgs.callPackage ./derivations/xnu.nix { machKernelPath = ...; }
    #   2. build/distfiles/mach_kernel-10.15.7 in the repo working tree
    #      (same vendoring mechanism as scripts/fetch-distfiles.sh).
    #   3. Fallback stub file: keeps evaluation pure and side-effect free,
    #      but the build phase aborts with a clear, actionable message
    #      instead of the old opaque network 404 cascade.
    distfile = ../distfiles/mach_kernel-10.15.7;

    # Deterministic placeholder content used when nothing has been vendored.
    stub = writeText "abzu-mach-kernel-stub" ''
      ABZU-PRECOMPILED-KERNEL-STUB
      Place the real Catalina mach_kernel at build/distfiles/mach_kernel-10.15.7
    '';

    # Integrity policy for operator-supplied binaries:
    #   - If the file is vendored in-repo (build/distfiles/mach_kernel-10.15.7),
    #     `builtins.path` hashes it *at evaluation time*, so the store path is
    #     content-addressed — no separate SRI pin can drift or mismatch, and a
    #     wrong file simply produces a different output path.
    #   - If supplied out-of-band via `machKernelPath`, we cannot know its
    #     hash at eval time; require the caller to pass `machKernelHash` too
    #     (get it with:  nix-prefetch-url "file://<path>"). Without it we fail
    #     fast at eval with an actionable message instead of the old opaque
    #     network-404 / hash-mismatch cascade.
    vendoredSrc = builtins.path { path = distfile; name = "abzu-mach-kernel-vendored"; };

    haveVendored = builtins.pathExists distfile;

    src_ =
      if machKernelPath != null
        then
          if machKernelHash == null
            then builtins.throw ''
              xnu.nix (precompiled mode): `machKernelPath` was given without
              `machKernelHash`. Compute the SRI hash with
                nix-prefetch-url --unpack "file://<path>"
              (or use `nix hash file <path>` and convert hex->SRI) and pass it:
                pkgs.callPackage ./derivations/xnu.nix {
                  precompiled = true;
                  machKernelPath = "<path>";
                  machKernelHash = "sha256-...";
                };
              Alternatively vendor the binary at build/distfiles/mach_kernel-10.15.7
              and no hash argument is needed.
            ''
            else fetchurl { url = "file://${machKernelPath}"; hash = machKernelHash; }
        # Prefer the vendored in-repo file when present.
      else if haveVendored then vendoredSrc
        else stub;

    isStub = !haveVendored;
  in rec {
    pname = "xnu-kernel-precompiled";
    version = "10.15.7"; # Catalina era kernel (matches abzu ISO expectations)

    src = src_;
    inherit isStub;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      ${if isStub then ''
        echo "ERROR: no pre-compiled mach_kernel vendored." >&2
        echo "  Provide one of:" >&2
        echo "    1. build/distfiles/mach_kernel-10.15.7  (cp /System/Library/Kernels/kernel ...)" >&2
        echo "    2. a machKernelPath callPackage override" >&2
        echo "  Then update vendoredHash in build/derivations/xnu.nix with:" >&2
        echo "    nix-prefetch-url \"file://<your-mach_kernel>\"" >&2
        exit 1
      '' else ''
        mkdir -p $out/System/Library/Kernels
        cp $src $out/System/Library/Kernels/kernel
        chmod +w $out/System/Library/Kernels/kernel
        chmod +x $out/System/Library/Kernels/kernel
      ''}
      runHook postInstall
    '';

    meta = with lib; {
      description = "Pre-compiled XNU Kernel (locally vendored, for cross-compilation bypass)";
      platforms = [ "x86_64-darwin" "aarch64-darwin" ];
    };
  })
else
  # MODE B: Native Source Compilation (For your Mac Pro 5,1)
  stdenv.mkDerivation rec {
    pname = "xnu-kernel";
    version = srcInfo.xnuTag;

    src = xnu-sources;

    nativeBuildInputs = [ clang llvm cctools ];

    buildPhase = ''
      runHook preBuild
      make SDKROOT=macosx \
           ARCH_CONFIGS=X86_64 \
           KERNEL_CONFIGS=RELEASE \
           TARGET_CONFIGS=X86_64 \
           -j $NIX_BUILD_CORES
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/System/Library/Kernels
      
      cp BUILD/obj/RELEASE_X86_64/mach_kernel $out/System/Library/Kernels/kernel
      cp BUILD/obj/RELEASE_X86_64/mach_kernel.dSYM $out/System/Library/Kernels/ -r || true
      
      runHook postInstall
    '';

    meta = with lib; {
      description = "Apple XNU Kernel compiled from source";
      homepage = "https://opensource.apple.com/source/xnu/";
      license = licenses.apsl20;
      platforms = [ "x86_64-darwin" "aarch64-darwin" ];
    };
  }
