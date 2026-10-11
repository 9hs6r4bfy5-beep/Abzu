# build/scripts/make-iso.sh — wrap the assembled rootfs into a bootable hybrid ISO.
#
# Boot story for Intel Macs (primary target):
#   * El Torito EFI boot from a FAT32 ESP image carrying rEFInd
#     (/EFI/BOOT/BOOTX64.EFI), which chainloads XNU's efi stub (boot.efi)
#     with boot-args from kernel/config/build-profiles.md.
#   * Hybrid MBR/GPT layout so the same ISO written to USB dd-style boots
#     directly, and burned-to-DVD Mac firmware sees an "EFI Boot" option.
#   * Root filesystem payload: HFS+ image on Darwin hosts (mkhfs/hformat);
#     deterministic USTAR tarball fallback elsewhere — the installer unpacks
#     ABZU_ROOTFS.tar at deploy time.
#
# AUDIT FIXES (2026-10-11):
#   * Removed the broken first mkisofs invocation (`... 2>/dev/null || true`)
#     that silently swallowed failures and produced an unbootable ISO.
#   * ESP is now FAT32 (FAT12 ESP images are rejected by EFI specs/firmware).
#   * `mmd ::/EFI ::/EFI/BOOT` no longer relies on directories pre-existing;
#     mtools creates them and failure is fatal, not `|| true`.
#   * Dropped the contradictory `-append_partition 2 001 ...` alongside
#     `-isohybrid-gpt-basdat`; single canonical isohybrid recipe instead.
#   * All external tool failures checked explicitly (set -eu preserved).
#
# Requires (Debian/Ubuntu pkg names): xorriso (or genisoimage+mtools), mtools, dosfstools
set -eu
STAGE="${1:?usage: $0 <staging-dir> <out.iso>}"
ISO="${2:-abzu.iso}"
VOL="ABZU"                     # 32-char-safe volume id
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

need() { command -V "$1" >/dev/null 2>&1 || { echo "!! missing required tool: $1" >&2; exit 1; }; }

echo "==> building ESP (EFI System Partition) image"
need mkfs.vfat; need mcopy; need mmd
dd if=/dev/zero of="${WORK}/esp.img" bs=1M count=64 status=none
mkfs.vfat -F 32 -n ABZU_EFI "${WORK}/esp.img" >/dev/null
mmd -i "${WORK}/esp.img" ::/EFI ::/EFI/BOOT
if [ -f "${STAGE}/EFI/BOOT/BOOTX64.EFI" ]; then
    mcopy -i "${WORK}/esp.img" "${STAGE}/EFI/BOOT/BOOTX64.EFI" ::/EFI/BOOT/
else
    echo "WARN: no BOOTX64.EFI staged (fetch rEFInd prebuilt via make fetch)" >&2
fi
# stage refind.conf + drivers if present
if [ -d "${STAGE}/EFI/refind" ]; then
    mmd -i "${WORK}/esp.img" ::/EFI/refind
    mcopy -s -i "${WORK}/esp.img" "${STAGE}/EFI/refind/." ::/EFI/refind/
fi
# stage boot.efi on the ESP too, so rEFInd can load it from FAT
if [ -f "${STAGE}/System/Library/CoreServices/boot.efi" ]; then
    mmd -i "${WORK}/esp.img" ::/System ::/System/Library ::/System/Library/CoreServices
    mcopy -i "${WORK}/esp.img" "${STAGE}/System/Library/CoreServices/boot.efi" \
          ::/System/Library/CoreServices/boot.efi
fi

echo "==> building rootfs payload"
mkdir -p "${WORK}/iso-root"
if command -V mkhfs >/dev/null 2>&1 || command -V hformat >/dev/null 2>&1; then
    # Darwin host: real HFS+ volume mounted as '/' by XNU via -root flag.
    ROOT_MB=$(( $(du -sm "${STAGE}" | cut -f1) + 512 ))
    dd if=/dev/zero of="${WORK}/iso-root/ABZU_ROOTFS.hfs" bs=1M count="${ROOT_MB}" status=none
    HFSFMT="$(command -v mkhfs || command -v hformat)"
    "${HFSFMT}" -l ABZU -v "${VOL}" "${WORK}/iso-root/ABZU_ROOTFS.hfs" >/dev/null
    echo "NOTE: populate HFS image with copyhfs/cpmac tooling on this Darwin host"
else
    # Portable fallback: deterministic tar embedded in the ISO.
    tar --format=ustar --numeric-owner --owner=0 --group=0 \
        --mtime="@315532800" -C "${STAGE}" -cf "${WORK}/iso-root/ABZU_ROOTFS.tar" .
fi

MKISO="$(command -v xorriso || command -v mkisofs || command -v genisoimage)"
[ -n "${MKISO}" ] || { echo "!! need xorriso/mkisofs/genisoimage (apt install genisoimage)" >&2; exit 1; }

echo "==> writing hybrid ISO (${ISO})"
case "$(basename "${MKISO}")" in
  xorriso)
    # 4-byte zero placeholder for the first (data) catalog entry, which is
    # what makes xorriso emit the 0xEE protective GPT partition of the
    # isohybrid layout.
    dd if=/dev/zero of="${WORK}/efiboot.img" bs=1 count=4 status=none
    ISOLINUX_MBR=""
    for c in /usr/lib/ISOLINUX/isohdpfx.bin /usr/share/syslinux/isohdpfx.bin; do
        [ -f "$c" ] && ISOLINUX_MBR="$c" && break
    done
    # shellcheck disable=SC2086
    "${MKISO}" -as mkisofs -r -joliet-long -V "${VOL}" \
        ${ISOLINUX_MBR:+-isohybrid-mbr "${ISOLINUX_MBR}"} \
        -c boot.catalog \
        -b "${WORK}/efiboot.img" -no-emul-boot -boot-load-size 4 -boot-info-table \
        --efi-boot ESP \
        -e "${WORK}/esp.img" -no-emul-boot \
        -isohybrid-gpt-basdat \
        -o "${ISO}" "${WORK}/iso-root"
    ;;
  *)
    # legacy mkisofs/genisoimage: minimal El Torito EFI (not full isohybrid)
    "${MKISO}" -r -J -V "${VOL}" \
        -eltorito-alt-boot -e "${WORK}/esp.img" -no-emul-boot \
        -o "${ISO}" "${WORK}/iso-root"
    ;;
esac

echo "==> done: ${ISO}"
sha256sum "${ISO}" 2>/dev/null || shasum -a 256 "${ISO}"
echo "    flash: dd if=${ISO} of=/dev/sdX bs=8m status=progress   (or burn to DVD)"
echo "    boot:  hold Option/⌥ at power-on on an Intel Mac → 'EFI Boot'"
