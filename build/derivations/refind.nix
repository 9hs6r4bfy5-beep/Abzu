# refind.nix — rEFInd EFI bootloader (GPLv3) staged for the ISO's ESP image.
# Prebuilt binary release; we only repack it into an ESP-shaped tree.
{ lib, stdenvNoCC, runCommand, fetchzip }:

let
  version = "0.14.0.2";
  src = fetchzip {
    url = "https://sourceforge.net/projects/refind/files/${version}/refind-bin-${version}.zip";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # refreshed by scripts/update-src-hashes.sh
    stripRoot = false;
  };
in runCommand "abzu-refind-${version}" {
  meta.description = "rEFInd ${version} EFI boot manager staged for Abzu";
} ''
  set -e
  mkdir -p $out/EFI/BOOT $out/EFI/refind
  R="${src}/refind-bin-${version}"
  
  [ -d "$R/drivers_x64" ] && cp -r "$R/drivers_x64" $out/EFI/refind/drivers_x64 || true

  # Extract rEFInd binaries (Include 64-bit, ARM64, and 32-bit for MBP 4,1 compatibility)
  # CRITICAL: EFI executables MUST be 755 (executable), or the firmware will reject them.
  [ -f "$R/refind_x64" ] && install -m755 "$R/refind_x64" $out/EFI/BOOT/BOOTX64.EFI || true
  [ -f "$R/refind_aa64" ] && install -m755 "$R/refind_aa64" $out/EFI/BOOT/BOOTAA64.EFI || true
  [ -f "$R/refind_ia32" ] && install -m755 "$R/refind_ia32" $out/EFI/BOOT/BOOTIA32.EFI || true # CRITICAL for MBP 4,1

  # Generate a clean, Abzu-themed rEFInd configuration
  cat > $out/EFI/refind/refind.conf <<'CONF'
timeout 5
showtools shutdown, reboot, exit
volume_label ABZU_ROOTFS
# rEFInd will auto-detect the XNU kernel in /System/Library/Kernels/
# We provide a custom menu entry to ensure it boots cleanly
menuentry "Abzu Darwin" {
    icon \EFI\refind\icons\os_mac.png
    volume "ABZU_ROOTFS"
    loader \System\Library\Kernels\kernel
    options "root=UUID=ABZU-ROOTFS rdshell=0"
}
CONF
''
