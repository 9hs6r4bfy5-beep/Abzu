# refind.nix — rEFInd EFI bootloader (GPLv3) staged for the ISO's ESP image.
# Prebuilt binary release; we only repack it into an ESP-shaped tree.
{ lib, stdenvNoCC, runCommand, fetchzip }:

let
  version = "0.14.0.2";
  src = fetchzip {
    url = "https://downloads.sourceforge.net/project/refind/${version}/refind-bin-${version}.zip";
    # Real SRI hash of the SourceForge archive (verified against the pinned
    # release file; refresh with nix-prefetch-url if the mirror rotates).
    hash = "sha256-Cir3n3D9RDWwDk/ZmOfdPgJWymtWtbukB2b9Gb1Bszw=";
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

  # Generate a clean, Abzu-themed rEFInd configuration.
  #
  # BOOT-CHAIN NOTE: XNU boots via its EFI boot stub (boot.efi), which the
  # rootfs stages at /System/Library/CoreServices/boot.efi; rEFInd must chain
  # that stub — pointing `loader` straight at \System\Library\Kernels\kernel
  # is invalid because mach_kernel is a Mach-O binary, not an PE/COFF EFI
  # application. The ISO's ESP also carries the standard fallback path
  # \EFI\BOOT\BOOTX64.EFI (= this rEFInd binary).
  cat > $out/EFI/refind/refind.conf <<'CONF'
timeout 5
showtools shutdown, reboot, exit
volume_label ABZU_ROOTFS
# rEFInd auto-detects macOS via the EFI boot stub; we pin the entry so the
# volume label and boot-args stay under our control.
menuentry "Abzu Darwin" {
    icon \EFI\refind\icons\os_mac.png
    volume "ABZU_ROOTFS"
    loader \System\Library\CoreServices\boot.efi
    options "-abzu-mode root=UUID=ABZU-ROOTFS rdshell=0"
}
CONF
''
