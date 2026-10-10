# build/derivations/iso.nix
# Generates a hybrid El Torito bootable ISO for Intel Macs (x86_64)
# Built natively on the host (e.g., aarch64-darwin), but packages x86_64-darwin binaries.
{ lib, stdenvNoCC, runCommand, rootfs, refind, xorriso, mtools ? null, libisoburn ? null, volumeLabel ? "ABZU_ROOTFS" }:

stdenvNoCC.mkDerivation rec {
  pname = "abzu-iso-intel";
  version = "0.1.0";

  # CRITICAL FIX: Filter out nulls to prevent derivationStrict from crashing 
  # on missing packages (like libisoburn on aarch64-darwin).
  nativeBuildInputs = [ xorriso ] ++ lib.filter (x: x != null) [ mtools libisoburn ];

  buildCommand = ''
    runHook preBuild
    
    # Deterministic timestamps for everything baked into the image
    export SOURCE_DATE_EPOCH="315532800"
    
    mkdir -p $out/iso_root
    mkdir -p $out/esp/EFI/BOOT
    mkdir -p $out/esp/EFI/refind

    # 1. Stage the Darwin Root Filesystem (HFS+ compatible structure)
    echo "==> Staging rootfs..."
    cp -r ${rootfs}/. $out/iso_root/

    # 2. Stage rEFInd (Includes bootia32.efi for MBP 4,1)
    echo "==> Staging rEFInd..."
    cp -r ${refind}/EFI/BOOT/. $out/esp/EFI/BOOT/
    cp -r ${refind}/EFI/refind/. $out/esp/EFI/refind/

    # 3. Create the Hybrid ISO using xorriso
    echo "==> Building hybrid El Torito ISO..."
    ${xorriso}/bin/xorriso -as mkisofs \
      -hfsplus \
      -apm-block-size 2048 \
      -efi-boot-part \
      --efi-boot-image \
      -no-emul-boot \
      -V "${volumeLabel}" \
      -o $out/abzu-intel-installer.iso \
      $out/iso_root \
      $out/esp

    echo "==> ISO successfully created at: $out/abzu-intel-installer.iso"
    
    runHook postBuild
  '';

  meta = with lib; {
    description = "Bootable ISO image for Abzu Darwin (Intel x86_64), built natively on Apple Silicon";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
  };
}
