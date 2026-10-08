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
  meta.description = "rEFInd ${version} EFI boot manager staged at /EFI/BOOT/BOOTX64.EFI";
} ''
  set -e
  mkdir -p $out/EFI/BOOT $out/EFI/refind
  R="${src}/refind-bin-${version}"
  [ -d "$R/drivers_x64" ] && cp -r "$R/drivers_x64" $out/EFI/refind/drivers_x64 || true

  # Extract rEFInd binaries (Include BOTH 64-bit and 32-bit for MBP 4,1 compatibility)
  # NB: $src is already unpacked by fetchzip, so no `unzip` step is needed here.
  # refind_x64 → BOOTX64.EFI so any EFI firmware auto-finds it without NVRAM.
  [ -f "$R/refind_x64" ] && install -m644 "$R/refind_x64" $out/EFI/BOOT/BOOTX64.EFI || true
  [ -f "$R/refind_aa64" ] && install -m644 "$R/refind_aa64" $out/EFI/BOOT/BOOTAA64.EFI || true
  [ -f "$R/refind_ia32" ] && install -m644 "$R/refind_ia32" $out/EFI/BOOT/BOOTIA32.EFI || true # CRITICAL for MBP 4,1
  cat > $out/EFI/refind/refind.conf <<'CONF'
timeout 5
showtools shutdown,reboot
volume_label ABZU_ROOTFS
defaultloader /System/Library/Kernels/kernel
alsoadd /System/Library/Kernels/kernel "Abzu" keeptools
CONF
''
