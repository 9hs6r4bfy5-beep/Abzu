# build/derivations/iso.nix
# Generates a hybrid El Torito bootable ISO for Intel Macs (x86_64)
# Built natively on the host (e.g., aarch64-darwin), but packages x86_64-darwin binaries.
{ lib, stdenvNoCC, runCommand, rootfs, refind, xorriso, mtools, libisoburn }:

stdenvNoCC.mkDerivation rec {
  pname = "abzu-iso-intel";
  version = "0.1.0";

  nativeBuildInputs = [ xorriso mtools libisoburn ];

  # We don't need to cross-compile the ISO builder itself, just its inputs
  buildCommand = ''
    runHook preBuild
    
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
    xorriso -as mkisofs \
      -hfsplus \
      -apm-block-size 2048 \
      -efi-boot-part \
      --efi-boot-image \
      -no-emul-boot \
      -V "Abzu_Install" \
      -o $out/abzu-intel-installer.iso \
      $out/iso_root \
      $out/esp

    echo "==> ISO successfully created at: $out/abzu-intel-installer.iso"
    
    runHook postBuild
  '';

  meta = with lib; {
    description = "Bootable ISO image for Abzu Darwin (Intel x86_64)";
    platforms = [ "x86_64-darwin" ];
  };
}
