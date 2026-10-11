# build/derivations/xnu.nix
# Unified XNU kernel derivation: supports local pre-compiled binary fetching
# to bypass cross-compilation SDK requirements.
#
# AUDIT FIXES (2026-10-11):
#   * MODE B previously referenced an undeclared `stdenv` -> evaluation error
#     "attribute 'stdenv' missing". Now takes stdenv as a function argument
#     (flake.nix injects it automatically via callPackage).
#   * MODE A previously used placeholder SRI hashes ("sha256-AAAA...") which
#     Nix rejects at eval time as malformed digests. Replaced with lib.fakeSha256
#     so evaluation succeeds and the real hash is reported by Nix on first run;
#     then paste the "got:" value into `kernelHash` below (or set
#     `abzu.kernelPath`/`abzu.kernelHash` when calling the flake).
#   * The dead fallback URL (github.com/jprx/mock-kernel-2023, HTTP 404) is
#     gone. Without a local kernelPath the derivation now fails FAST with a
#     clear message instead of a confusing network/hash error.
#   * Kernel patches are now actually applied in MODE B (they were passed in
#     but never referenced before).
#   * MODE A also stages a Catalina-style CoreServices/boot.efi path marker so
#     rEFInd's loader line resolves once the user supplies boot.efi alongside
#     the kernel file (see NOTE below).
{ lib, stdenv, stdenvNoCC, fetchurl, clang ? null, llvm ? null, cctools ? null
, xnu-sources ? null, patches ? []
, precompiled ? false
, kernelPath ? null      # absolute path to mach_kernel copied off your Catalina install
, kernelHash ? lib.fakeSha256   # SRI sha256 of that file: nix hash path <file>
, bootEfiPath ? null     # optional absolute path to /System/Library/CoreServices/boot.efi
, bootEfiHash ? lib.fakeSha256
} @args:

if precompiled then
  # MODE A: Pre-compiled binary (local file supplied by the user)
  stdenvNoCC.mkDerivation rec {
    pname = "xnu-kernel-precompiled";
    version = "custom-intel";

    # No implicit network access: fail closed with an actionable message.
    src =
      if kernelPath == null then
        throw ''
          abzu: no Intel XNU kernel binary available.
          Copy these files off your Catalina (10.15.x) install and pass them in:
            kernelPath  = /path/to/mach_kernel           (from /System/Library/Kernels/kernel)
            bootEfiPath = /path/to/boot.efi              (from /System/Library/CoreServices/boot.efi)
          Compute hashes with:  nix hash path --mode=SRI <file>
          Then either edit build/flake.nix (xnu-kernel-precompiled call) or set
          nixpkgs config overrides, e.g.:
            nix build .#iso-intel --override abzu-kernel-path "$HOME/catalina/mach_kernel"
        ''
      else
        fetchurl { url = "file://${kernelPath}"; hash = kernelHash; };

    bootEfiSrc =
      if bootEfiPath == null then null
      else fetchurl { url = "file://${bootEfiPath}"; hash = bootEfiHash; };

    phases = [ "installPhase" ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/System/Library/Kernels" "$out/System/Library/CoreServices"
      cp "$src" "$out/System/Library/Kernels/kernel"
      chmod 644 "$out/System/Library/Kernels/kernel"
      ${if bootEfiSrc != null then ''
        cp "${bootEfiSrc}" "$out/System/Library/CoreServices/boot.efi"
        chmod 644 "$out/System/Library/CoreServices/boot.efi"
      '' else ''
        echo "WARN: boot.efi not supplied — ISO will not chainload XNU's EFI stub." >&2
      ''}
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

    # AUDIT FIX: patches were previously accepted as an argument and silently
    # dropped. Apply them against the git identity created by xnu-sources.nix.
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
      mkdir -p $out/System/Library/Kernels $out/System/Library/CoreServices
      cp BUILD/obj/RELEASE_X86_64/mach_kernel $out/System/Library/Kernels/kernel
      cp -r BUILD/obj/RELEASE_X86_64/mach_kernel.dSYM $out/System/Library/Kernels/ || true
      # Stage the EFI boot stub if the build produced one, so rootfs has
      # /System/Library/CoreServices/boot.efi for rEFInd's loader line.
      if [ -f BUILD/obj/RELEASE_X86_64/boot.efi ]; then
        cp BUILD/obj/RELEASE_X86_64/boot.efi $out/System/Library/CoreServices/boot.efi
      fi
      runHook postInstall
    '';

    meta = with lib; {
      description = "Apple XNU kernel compiled from source";
      homepage = "https://opensource.apple.com/source/xnu/";
      license = licenses.apsl20;
      platforms = [ "x86_64-darwin" ];
    };
  }
