# build/derivations/xnu.nix
# Compiles the Apple XNU kernel for x86_64-darwin (Intel Macs)
# When called via pkgsCrossIntel.callPackage, `stdenv` is ALREADY the x86_64-darwin cross-stdenv.
#
# NOTE: `patches` must be declared as a parameter here — the flake passes
# `patches = ../kernel/patches` and undeclared arguments used to be silently
# dropped, so the Abzu patch set never reached the build. The flake now passes
# an explicit *list* of patch files (sorted glob of the patch directory).
{ lib, stdenv, clang, llvm, cctools, xnu-sources, srcInfo, patches ? [] }:

stdenv.mkDerivation rec {
  pname = "xnu-kernel-intel";
  version = srcInfo.xnuTag; # e.g., "xnu-7195.141.2"

  src = xnu-sources;

  # Native build tools run on the host (aarch64-darwin M4)
  nativeBuildInputs = [ clang llvm cctools ];

  # XNU's Makefile builds inside the xnu/ subdirectory of the assembled
  # source tree (siblings IOKitUser/, libc/ are where Apple's makefiles
  # expect them — see xnu-sources.nix + config/sources.json).
  sourceRoot = "source/xnu";

  # Apply the Abzu patch set in sorted order; the re-rolled diffs under
  # ../../kernel/patches carry valid hunk headers, so git apply works.
  # NOTE: -p1 (the stdenv default) is REQUIRED: the .patch files are
  # `git diff`-style with a/... b/ prefixes, and kernel/build-xnu.sh feeds
  # them to plain `git apply` (which also defaults to -p1). Do not change
  # this back to -p0 — nothing would match and the patches would silently
  # no-op or fail depending on the phase runner.
  inherit patches;
  patchFlags = [ "-p1" ];

  buildPhase = ''
    runHook preBuild

    # XNU's make system requires specific SDK and architecture flags
    make SDKROOT=macosx \
         ARCH_CONFIGS=X86_64 \
         KERNEL_CONFIGS=RELEASE \
         TARGET_CONFIGS=X86_64 \
         -j $NIX_BUILD_CORES

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/System/Library/Kernels $out/System/Library/CoreServices \
             $out/bootstrap

    # The compiled Intel kernel
    cp BUILD/obj/RELEASE_X86_64/mach_kernel $out/System/Library/Kernels/kernel

    # Also copy the dSYM for debugging (optional but recommended)
    cp BUILD/obj/RELEASE_X86_64/mach_kernel.dSYM $out/System/Library/Kernels/ -r || true

    # Stage the EFI boot stub location that rEFInd chainloads
    # (\System Library\CoreServices\boot.efi). mach_kernel itself is a Mach-O
    # binary, not a PE/COFF EFI application — the stub is mandatory for any
    # EFI boot. It ships with installed macOS; when building on a Darwin host
    # that has it we copy it through, otherwise drop a placeholder note so the
    # ISO builder fails loudly rather than silently producing an unbootable ESP.
    if [ -f /System/Library/CoreServices/boot.efi ]; then
      install -m644 /System/Library/CoreServices/boot.efi \
                    $out/System/Library/CoreServices/boot.efi
    else
      echo "boot.efi must be supplied from a Darwin host (see kernel/config/build-profiles.md)" \
           > $out/System/Library/CoreServices/boot.efi.placeholder
    fi

    # Bootstrap payload consumed by rootfs staging (rootfs-slim copies /bootstrap)
    : > $out/bootstrap/.abzu-kernel-staged

    runHook postInstall
  '';

  meta = with lib; {
    description = "Apple XNU Kernel compiled for x86_64-darwin (Intel Macs)";
    homepage = "https://opensource.apple.com/source/xnu/";
    license = licenses.apsl20;
    platforms = [ "x86_64-darwin" ];
  };
}
