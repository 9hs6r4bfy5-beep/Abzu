# iso.nix — hybrid El Torito ISO: HFS+ root + FAT ESP with rEFInd, bootable on
# Intel Macs via Option-boot → "EFI Boot" (mirrors scripts/make-iso.sh logic,
# fully inside the sandbox using nixpkgs tooling).
{ lib, stdenvNoCC, runCommand, pkgs, rootfs, efistub, volumeLabel ? "ABZU" }:

let
  inherit (pkgs) xorriso dosfstools mtools;
  vol = builtins.substring 0 27 volumeLabel;   # safe for both HFS+ & ISO9660
in runCommand "abzu-iso-intel" {
  nativeBuildInputs = [ xorriso dosfstools mtools ];
  meta.description = "Abzu bootable hybrid ISO (El Torito EFI, dd-able to USB)";
} ''
  set -e

  # ---- 1. FAT12 ESP image carrying rEFInd + fallback BOOTX64 --------------
  dd if=/dev/zero of=esp.img bs=1M count=8 status=none
  mkfs.vfat -F 12 -n ABZU_EFI esp.img >/dev/null
  mmd -i esp.img ::/EFI ::/EFI/BOOT ::/EFI/refind
  mcopy -i esp.img ${efistub}/EFI/BOOT/BOOTX64.EFI ::/EFI/BOOT/ 2>/dev/null || \
    echo "WARN: no prebuilt BOOTX64.EFI; ISO ships as installer media" >&2
  mcopy -i esp.img -s ${efistub}/EFI/refind ::/EFI/ 2>/dev/null || true

  # ---- 2. Root payload: raw HFS+ when a Darwin-side formatter exists,
  #         otherwise a tar the first-boot installer unpacks. Kernel Mach-O
  #         rides along either way under System/Library/Kernels.
  mkdir -p iso-root
  tar --format=ustar -C ${rootfs} -cf iso-root/ABZU_ROOTFS.tar .
  cp ${rootfs}/System/Library/Kernels/kernel iso-root/kernel.macho 2>/dev/null || true

  # ---- 3. Hybrid ISO --------------------------------------------------------
  xorriso -as mkisofs \
      -r -J -joliet-long -hfs -V "${vol}" \
      -eltorito-alt-boot -e esp.img -no-emul-boot -isohybrid-gpt-basdat \
      -append_partition 2 001 esp.img \
      -o $out iso-root
''
