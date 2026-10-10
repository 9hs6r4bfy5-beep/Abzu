# build/derivations/xnu.nix
# Unified XNU kernel derivation: supports local pre-compiled binary fetching 
# to bypass cross-compilation SDK requirements.
{ lib, stdenvNoCC, fetchurl, clang ? null, llvm ? null, cctools ? null, xnu-sources ? null, srcInfo, patches ? [], precompiled ? false, kernelPath ? null }:

if precompiled then
  # MODE A: Pre-compiled binary (Local file or URL)
  stdenvNoCC.mkDerivation rec {
    pname = "xnu-kernel-precompiled";
    version = "custom-intel";

    # If kernelPath is provided, use it as a local file. Otherwise, fallback to a URL.
    src = if kernelPath != null then
      fetchurl {
        url = "file://${kernelPath}";
        # You will get the real hash in Step 3
        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      }
    else
      fetchurl {
        # Fallback URL (update if a stable public mirror is found)
        url = "https://github.com/jprx/mock-kernel-2023/raw/main/mach_kernel.orig";
        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };

    buildCommand = ''
      runHook preBuild
      mkdir -p $out/System/Library/Kernels
      cp $src $out/System/Library/Kernels/kernel
      chmod +x $out/System/Library/Kernels/kernel
      runHook postBuild
    '';

    meta = with lib; {
      description = "Pre-compiled x86_64 XNU Kernel (from local Intel Mac)";
      platforms = [ "x86_64-darwin" ];
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
