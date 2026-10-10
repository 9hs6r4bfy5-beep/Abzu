# build/derivations/xnu.nix
# Unified XNU kernel derivation: supports both native source compilation 
# and pre-compiled binary fetching (for cross-compilation SDK workarounds).
{ lib, stdenv, stdenvNoCC, fetchurl, clang, llvm, cctools, xnu-sources, srcInfo, patches ? [], precompiled ? false }:

if precompiled then
  stdenvNoCC.mkDerivation rec {
    pname = "xnu-kernel-precompiled";
    version = "10.15.7";

    src = fetchurl {
      url = "https://github.com/kholia/OSX-KVM/raw/master/OpenCore-Catalina/mach_kernel";
      hash = "sha256-YOUR_REAL_HASH_HERE="; 
    };

    buildCommand = ''
      runHook preBuild
      mkdir -p $out/System/Library/Kernels
      cp $src $out/System/Library/Kernels/kernel
      chmod +x $out/System/Library/Kernels/kernel
      runHook postBuild
    '';

    meta = with lib; {
      description = "Pre-compiled XNU Kernel (for cross-compilation bypass)";
      platforms = [ "x86_64-darwin" "aarch64-darwin" ];
    };
  }
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
