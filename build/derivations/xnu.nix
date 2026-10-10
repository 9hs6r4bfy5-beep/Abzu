# build/derivations/xnu.nix
# Compiles the Apple XNU kernel.
# When called via pkgsCrossIntel.callPackage, `stdenv` is ALREADY the correct cross-stdenv.
{ lib, stdenv, clang, llvm, cctools, xnu-sources, srcInfo, patches ? [] }:

stdenv.mkDerivation rec {
  pname = "xnu-kernel";
  version = srcInfo.xnuTag;

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
    
    # The compiled kernel
    cp BUILD/obj/RELEASE_X86_64/mach_kernel $out/System/Library/Kernels/kernel
    
    # Also copy the dSYM for debugging (optional but recommended)
    cp BUILD/obj/RELEASE_X86_64/mach_kernel.dSYM $out/System/Library/Kernels/ -r || true
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Apple XNU Kernel";
    homepage = "https://opensource.apple.com/source/xnu/";
    license = licenses.apsl20;
    platforms = [ "x86_64-darwin" "aarch64-darwin" ];
  };
}
