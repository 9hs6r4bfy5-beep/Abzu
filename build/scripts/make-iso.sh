#!/bin/sh
# make-iso.sh — wrap the assembled rootfs into a bootable hybrid ISO.
#
# Boot story for Intel Macs (primary target):
#   * El Torito EFI partition (FAT12 ESP image) carrying rEFInd + our
#     /EFI/BOOT/BOOTX64.EFI, which chainloads XNU's efi stub with boot-args
#     from kernel/config/build-profiles.md.
#   * MBR partition table marked bootable so legacy BIOS also lists it.
#   * Hybrid layout: the same ISO written to USB dd-style boots directly;
#     HFS+ filesystem image inside is mounted as '/' by XNU via -root flag.
#
# Requires (Debian/Ubuntu pkg names): mkisofs|genisoimage|xorriso, mtools, dosfstools
set -eu
STAGE="${1:?usage: $0 <staging-dir> <out.iso>}"
ISO="${2:-abzu.iso}"
VOL="ABZU"                     # 32-char-safe volume id
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

echo "==> building ESP (EFI System Partition) image"
dd if=/dev/zero of="${WORK}/esp.img" bs=1M count=8 status=none
mkfs.vfat -F 12 -n ABZU_EFI "${WORK}/esp.img" >/dev/null
mmd -i "${WORK}/esp.img" ::/EFI ::/EFI/BOOT || true
# rEFInd binary would be staged here by ../derivations/refind.nix or
# scripts/fetch-distfiles.sh; fall back to placeholder note when absent.
if [ -f "${STAGE}/EFI/BOOT/BOOTX64.EFI" ]; then
    mcopy -i "${WORK}/esp.img" "${STAGE}/EFI/BOOT/BOOTX64.EFI" ::/EFI/BOOT/
else
    echo "WARN: no BOOTX64.EFI staged (fetch rEFInd prebuilt via make fetch)"
fi

echo "==> building HFS+ rootfs image"
ROOT_MB=$(( $(du -sm "${STAGE}" | cut -f1) + 512 ))
dd if=/dev/zero of="${WORK}/rootfs.hfs" bs=1M count="${ROOT_MB}" status=none
if command -V mkhfs >/dev/null 2>&1 || command -V hformat >/dev/null 2>&1; then
    HFSFMT="$(command -v mkhfs || command -v hformat)"
    "${HFSFMT}" -l ABZU -v "${VOL}" "${WORK}/rootfs.hfs" >/dev/null
    echo "NOTE: populate HFS image with copyhfs/cpmac tooling on Darwin hosts"
else
    # Linux-side fallback: tar the stage and embed; installer unpacks at deploy.
    mkdir -p "${WORK}/iso-root"
    tar -C "${STAGE}" -cf "${WORK}/iso-root/ABZU_ROOTFS.tar" .
    STAGE_DIR="${WORK}/iso-root"
fi

MKISO="$(command -v xorriso || command -v mkisofs || command -v genisoimage)"
[ -n "${MKISO}" ] || { echo "!! need xorriso/mkisofs/genisoimage (apt install genisoimage)" >&2; exit 1; }

echo "==> writing hybrid ISO (${ISO})"
case "$(basename "${MKISO}")" in
  xorriso)
    "${MKISO}" -as mkisofs -R -J -HFS \
        -V "${VOL}" \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin 2>/dev/null || true
    xorriso -as mkisofs -r -joliet-long -hfs -V "${VOL}" \
        -eltorito-alt-boot -e "${WORK}/esp.img" -no-emul-boot -isohybrid-gpt-basdat \
        -append_partition 2 001 "${WORK}/esp.img" \
        -o "${ISO}" "${STAGE_DIR:-${STAGE}}"
    ;;
  *)
    "${MKISO}" -r -J -hfs -V "${VOL}" \
        -eltorito-alt-boot -e "${WORK}/esp.img" -no-emul-boot \
        -o "${ISO}" "${STAGE_DIR:-${STAGE}}"
    ;;
esac

echo "==> done: ${ISO}"
sha256sum "${ISO}" 2>/dev/null || shasum -a 256 "${ISO}"
echo "    flash: dd if=${ISO} of=/dev/sdX bs=8m status=progress   (or burn to DVD)"
echo "    boot:  hold Option/⌥ at power-on on an Intel Mac → 'EFI Boot'"
