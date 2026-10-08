# build/derivations/xnu.nix
# Compiles the Apple XNU kernel for x86_64-darwin (Intel Macs)
# When called via pkgsCrossIntel.callPackage, `stdenv` is ALREADY the x86_64-darwin cross-stdenv.
{ lib, stdenv, clang, llvm, cctools, xnu-sources, srcInfo }:

stdenv.mkDerivation rec {
  pname = "xnu-kernel-intel";
  version = srcInfo.xnuTag; # e.g., "xnu-7195.141.2"

  src = xnu-sources;

  # Native build tools run on the host (aarch64-darwin M4)
  nativeBuildInputs = [ clang llvm cctools ];

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
    mkdir -p $out/System/Library/Kernels
    
    # The compiled Intel kernel
    cp BUILD/obj/RELEASE_X86_64/mach_kernel $out/System/Library/Kernels/kernel
    
    # Also copy the dSYM for debugging (optional but recommended)
    cp BUILD/obj/RELEASE_X86_64/mach_kernel.dSYM $out/System/Library/Kernels/ -r || true
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Apple XNU Kernel compiled for x86_64-darwin (Intel Macs)";
    homepage = "https://opensource.apple.com/source/xnu/";
    license = licenses.apsl20;
    platforms = [ "x86_64-darwin" ];
  };
}
