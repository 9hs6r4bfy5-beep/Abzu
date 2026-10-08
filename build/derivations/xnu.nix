# build/derivations/xnu.nix
# Compiles the Apple XNU kernel for x86_64-darwin (Intel Macs)
# Designed to be cross-compiled from aarch64-darwin (Apple Silicon) hosts.
{ lib, stdenv, fetchurl, clang, llvm, cctools, xnu-sources, pkgsHost }:

# We force the build to target x86_64-darwin, regardless of the host machine
let
  targetPlatform = pkgsHost.pkgsCross.x86_64-darwin;
  crossStdenv = targetPlatform.stdenv;
in
crossStdenv.mkDerivation rec {
  pname = "xnu-kernel-intel";
  version = "7195.101.2"; # macOS 11.3 Big Sur (last highly open/buildable XNU)

  src = xnu-sources;

  # Native build tools (run on the Apple Silicon host)
  nativeBuildInputs = [ clang llvm cctools ];

  # Cross-compilation environment variables
  NIX_CFLAGS_COMPILE = "-target x86_64-apple-darwin";
  NIX_LDFLAGS = "-target x86_64-apple-darwin";

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
