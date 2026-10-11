# build/derivations/xnu.nix
# Unified XNU kernel derivation: supports local pre-compiled binary fetching
# to bypass cross-compilation SDK requirements.
{ lib, stdenv, stdenvNoCC, fetchurl, clang ? null, llvm ? null, cctools ? null
, xnu-sources ? null, srcInfo, patches ? []
, precompiled ? false
, kernelPath ? "/Users/alinamarsfelder/Downloads/mach_kernel"
# flake.nix threads the hash of the local mach_kernel through as `kernelHash`
# (and, for boot.efi, `bootEfiPath` / `bootEfiHash`). The lambda used to accept
# none of these, so `nix build .#iso-intel` died at eval time with:
#   error: function 'anonymous lambda' called with unexpected argument 'kernelHash'
# They are declared here so the call evaluates; kernelHash is consumed below in
# place of the hardcoded SRI hash.
, kernelHash ? null
, bootEfiPath ? null
, bootEfiHash ? null
}:

if precompiled then
  # MODE A: Pre-compiled binary (local file supplied by the user)
  stdenvNoCC.mkDerivation rec {
    pname = "xnu-kernel-precompiled";
    version = "10.15.7"; # Catalina era

    src =
      if kernelPath == null || ! builtins.pathExists kernelPath then
        throw ''
          abzu: no Intel XNU kernel binary available at ${toString kernelPath}.
          Copy the kernel off your Catalina (10.15.x) install:
            cp /System/Library/Kernels/kernel /path/to/mach_kernel
          Then update kernelPath in this file or flake.nix.
        ''
      else
        fetchurl {
          url = "file://${kernelPath}";
          # Honour the kernelHash threaded in from flake.nix (ABZU_KERNEL_HASH);
          # fall back to the historically pinned hash when none is given.
          sha256 = if kernelHash != null then kernelHash
                   else "1lqx1qwnsmzb9cb1gbzlmdaxi565zpk41d51h81zf7hip8rwa6av";
        };

    phases = [ "installPhase" ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/System/Library/Kernels"
      cp "$src" "$out/System/Library/Kernels/kernel"
      chmod 644 "$out/System/Library/Kernels/kernel"
      runHook postInstall
    '';

    meta = with lib; {
      description = "Pre-compiled x86_64 XNU Kernel (from local Intel Mac)";
      platforms = [ "x86_64-darwin" "x86_64-linux" "aarch64-darwin" "aarch64-linux" ];
    };
  }
else
  # MODE B: Native Source Compilation (For your Mac Pro 5,1, x86_64-darwin host)
  stdenv.mkDerivation rec {
    pname = "xnu-kernel";
    version = srcInfo.xnuTag;

    src = xnu-sources;
    sourceRoot = "abzu-xnu-sources-${srcInfo.xnuTag}/xnu";
    nativeBuildInputs = [ clang llvm cctools ];

    patchPhase = ''
      runHook prePatch
      for p in ${lib.concatMapStringsSep " " (x: ''"${x}"'') patches}; do
        echo "applying kernel patch: $p"
        git apply --whitespace=nowarn "$p"
      done
      runHook postPatch
    '';

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
      cp -r BUILD/obj/RELEASE_X86_64/mach_kernel.dSYM $out/System/Library/Kernels/ || true
      runHook postInstall
    '';

    meta = with lib; {
      description = "Apple XNU kernel compiled from source";
      homepage = "https://opensource.apple.com/source/xnu/";
      license = licenses.apsl20;
      platforms = [ "x86_64-darwin" ];
    };
  }
