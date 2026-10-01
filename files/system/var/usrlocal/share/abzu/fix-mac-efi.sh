#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# fix-mac-efi.sh — Finish/repair the boot chain on Intel Macs after a Fedora
# Atomic Desktop (Silverblue/Kinoionite/Bluefin/Abzu) install.
#
# WHY THIS EXISTS
#   MacBook Pro models 1,1 through ~5,2 (including the 4,1) ship 32-bit EFI
#   firmware on 64-bit CPUs. Two things go wrong there:
#
#     1. Anaconda's final "Configuring bootloader / Starting deployment"
#        step writes NVRAM boot entries and populates an EFI System
#        Partition. Old Mac firmware rejects the efibootmgr writes, and if
#        no FAT ESP exists yet (Apple's own layout uses HFS+), the whole
#        transaction aborts with only "An unknown error has occurred".
#     2. Even when the install completes, the resulting boot path is fragile
#        because Apple firmware ignores most of what efibootmgr wrote.
#
#   The system files themselves ARE fully written before that step fails,
#   so nothing is lost. This script mounts the installed system from a live
#   session, guarantees a FAT32 ESP exists, installs rEFInd (ia32 binaries
#   on 32-bit firmware, x64 otherwise) using ONLY fallback paths that Apple
#   firmware scans by itself, and never touches NVRAM. This is the same
#   setup (rEFInd present at install time) under which these machines are
#   known to install cleanly.
#
# HOW TO RUN IT
#   Boot the SAME Fedora live USB you installed from (Option-key picker ->
#   "EFI Boot"), open a terminal, and run:
#       sudo bash fix-mac-efi.sh
#   Then reboot, hold Option, pick "EFI Boot", and choose Abzu/Fedora in
#   the rEFInd menu.
#
#   From an already-booted system (e.g. after rebasing to Abzu) the same
#   script works locally; it detects that and repairs in place.
# =============================================================================

echo "--- Abzu Intel-Mac EFI repair ---"

if [ "$(id -u)" != "0" ]; then
    echo "Please run with sudo." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# 0. Detect firmware bitness. 32 = ia32-EFI Mac (2006-2008, e.g. MBP 4,1).
# -----------------------------------------------------------------------------
FW_BITS=64
if [ -d /sys/firmware/efi ] && [ -f /sys/firmware/efi/fw_platform_size ]; then
    FW_BITS=$(cat /sys/firmware/efi/fw_platform_size)
fi
echo "Firmware pointer size: ${FW_BITS}-bit EFI"

IN_LIVE_SESSION=0
if [ -f /run/initramfs/live ] || lsblk -nro LABEL,FSTYPE 2>/dev/null | grep -qE 'Fedora.*iso|LIVE'; then
    IN_LIVE_SESSION=1
fi

SYSROOT=/
if [ "$IN_LIVE_SESSION" = "1" ]; then
    # -------------------------------------------------------------------------
    # 1. Find the installed root partition (the one holding /ostree/repo or a
    #    Linux fstab) and mount it, plus everything in its fstab.
    # -------------------------------------------------------------------------
    ROOTDEV=""
    mkdir -p /mnt/sysroot-probe
    for dev in $(lsblk -pnro NAME,FSTYPE | awk '$2 ~ /^(ext[234]|xfs|btrfs)$/ {print $1}'); do
        if mount -o ro "$dev" /mnt/sysroot-probe 2>/dev/null; then
            if [ -d /mnt/sysroot-probe/ostree/repo ]; then
                umount /mnt/sysroot-probe
                ROOTDEV="$dev"
                break
            fi
            umount /mnt/sysroot-probe
        fi
    done
    rm -rf /mnt/sysroot-probe

    if [ -z "$ROOTDEV" ]; then
        echo "ERROR: No installed ostree system found on this disk."
        echo "Run the installer first (see docs/MAC-INSTALL.md, Step 1.3:"
        echo "create a 512 MiB FAT32 /boot/efi partition manually). The"
        echo "installer may still report 'unknown error' at the very end --"
        echo "that is fine; re-run THIS script afterwards."
        exit 1
    fi

    echo "Found installed root on: $ROOTDEV"
    SYSROOT=/mnt/sysroot
    mkdir -p "$SYSROOT"
    mount "$ROOTDEV" "$SYSROOT"

    # Mount /boot and the ESP per the installed fstab.
    while read -r dev mnt fst _rest; do
        [ "$mnt" = "/" ] && continue
        case "$fst" in swap|"") continue;; esac
        realdev="$dev"
        case "$dev" in UUID=*) realdev=$(blkid -U "${dev#UUID=}");; LABEL=*) realdev=$(blkid -L "${dev#LABEL=}");; esac
        [ -b "$realdev" ] || continue
        mkdir -p "$SYSROOT$mnt"
        mount "$realdev" "$SYSROOT$mnt" 2>/dev/null || echo "  (note: could not mount $mnt)"
    done < "$SYSROOT/etc/fstab"

    # Bind API filesystems so chroot tooling works.
    for d in dev proc sys run; do
        mkdir -p "$SYSROOT/$d"
        mount --rbind "/$d" "$SYSROOT/$d" 2>/dev/null || true
    done
fi

cleanup() {
    if [ "$SYSROOT" != "/" ]; then
        for d in run sys proc dev; do umount -R "$SYSROOT/$d" 2>/dev/null || true; done
        umount -R "$SYSROOT" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# -----------------------------------------------------------------------------
# 2. Guarantee a mounted FAT32 ESP at /boot/efi inside the target.
#    Older Macs often have NO real ESP (Apple blesses HFS+ instead). If none
#    exists, create a small one at the end of the root disk.
# -----------------------------------------------------------------------------
ESP="$SYSROOT/boot/efi"
mkdir -p "$ESP"

if ! mountpoint -q "$ESP"; then
    echo "No ESP mounted -- looking for a FAT partition in fstab..."
    FATDEV=$(awk '$2=="/boot/efi"{print $1}' "$SYSROOT/etc/fstab" 2>/dev/null || true)
    case "$FATDEV" in
        UUID=*) FATDEV=$(blkid -U "${FATDEV#UUID=}") ;;
        LABEL=*) FATDEV=$(blkid -L "${FATDEV#LABEL=}") ;;
    esac
    if [ -n "$FATDEV" ] && [ -b "$FATDEV" ]; then
        mount "$FATDEV" "$ESP" || true
    fi
fi

if ! mountpoint -q "$ESP"; then
    echo "Creating a new 512 MiB FAT32 ESP at the end of the disk."
    DISK=$(lsblk -nro PKNAME "$ROOTDEV" 2>/dev/null | head -1)
    [ -z "$DISK" ] && DISK=$(lsblk -nro PKNAME "$SYSROOT" 2>/dev/null | head -1)
    if [ -z "$DISK" ] || ! command -v parted >/dev/null; then
        echo "ERROR: Cannot create an ESP automatically here."
        echo "Boot the live USB, re-run the installer with a manual 512 MiB"
        echo "FAT32 /boot/efi partition (docs/MAC-INSTALL.md Step 1.3)."
        exit 1
    fi
    parted -s "$DISK" mkpart esp fat32 98% 100% || true
    partprobe "$DISK"; sleep 2
    NEWPART=$(lsblk -pnro NAME "$DISK" | tail -1)
    [ -b "$NEWPART" ] || { echo "ERROR: new partition not visible."; exit 1; }
    mkfs.vfat -F32 -n "EFI" "$NEWPART"
    mount "$NEWPART" "$ESP"
    UUID=$(blkid -o value -s UUID "$NEWPART")
    if ! grep -q "/boot/efi" "$SYSROOT/etc/fstab"; then
        echo "UUID=$UUID /boot/efi vfat defaults,uid=0,gid=0,umask=077,shortname=winnt 0 2" >> "$SYSROOT/etc/fstab"
    fi
    echo "ESP created: $NEWPART (UUID=$UUID), added to fstab."
fi
echo "ESP mounted at $ESP"

# -----------------------------------------------------------------------------
# 3. Install rEFInd binaries into the ESP. Use the ia32 build on 32-bit
#    firmware. We copy files directly (no efibootmgr, no NVRAM writes).
#    If the rEFInd package isn't in the target yet, try rpm-ostree, then
#    fall back to the live session's copy.
# -----------------------------------------------------------------------------
REFIND_SRC=""
if [ -d "$SYSROOT/usr/share/refind" ]; then
    REFIND_SRC="$SYSROOT/usr/share/refind"
elif [ -d /usr/share/refind ]; then
    REFIND_SRC=/usr/share/refind
else
    echo "Attempting to install rEFInd into the target via rpm-ostree..."
    chroot "$SYSROOT" rpm-ostree install rEFInd 2>/dev/null || \
        chroot "$SYSROOT" dnf -y install rEFInd 2>/dev/null || true
    [ -d "$SYSROOT/usr/share/refind" ] && REFIND_SRC="$SYSROOT/usr/share/refind"
fi
if [ -z "$REFIND_SRC" ]; then
    echo "ERROR: Could not find rEFInd files (package 'rEFInd')."
    echo "On a Silverblue base, first: rpm-ostree install rEFInd mactel-boot"
    exit 1
fi

BIN="refind_x64.efi"; DRV="drivers_x64"; TOOLS="tools_x64"
BOOTNAMES=(BOOTX64.EFI)
if [ "$FW_BITS" = "32" ]; then
    BIN="refind_ia32.efi"; DRV="drivers_ia32"; TOOLS="tools_ia32"
    # Apple 32-bit firmware legacy-scan names (both are checked; harmless
    # duplicates): standard UDC name plus Apple's own BOOTX86.EFI convention.
    BOOTNAMES=(BOOTIA32.EFI BOOTX86.EFI)
fi

echo "Installing $BIN from $REFIND_SRC ..."
mkdir -p "$ESP/EFI/refind" "$ESP/EFI/BOOT"
cp -v "$REFIND_SRC/$BIN" "$ESP/EFI/refind/refind.efi"
for n in "${BOOTNAMES[@]}"; do cp -v "$REFIND_SRC/$BIN" "$ESP/EFI/BOOT/$n"; done
[ -d "$REFIND_SRC/$DRV" ]   && cp -rv "$REFIND_SRC/$DRV"   "$ESP/EFI/refind/drivers_x86" || true
[ -d "$REFIND_SRC/$TOOLS" ] && cp -rv "$REFIND_SRC/$TOOLS" "$ESP/EFI/refind/tools_x86"   || true
[ -d "$REFIND_SRC/fonts" ]  && cp -rv "$REFIND_SRC/fonts"  "$ESP/EFI/refind/" || true
[ -d "$REFIND_SRC/icons" ]  && cp -rv "$REFIND_SRC/icons"  "$ESP/EFI/refind/" || true
[ -f "$REFIND_SRC/refind.conf-sample" ] && [ ! -f "$ESP/EFI/refind/refind.conf" ] && \
    cp "$REFIND_SRC/refind.conf-sample" "$ESP/EFI/refind/refind.conf"

# -----------------------------------------------------------------------------
# 4. Minimal drop-in config: short timeout, scan /boot for ostree kernels.
# -----------------------------------------------------------------------------
cat > "$ESP/EFI/refind/abzu.conf" <<'EOF'
# Abzu Intel-Mac boot options (managed by fix-mac-efi.sh).
timeout 3
use_graphics false
also_scan_guest_os false
scan_windows_fwfirmware false
EOF

# Make sure refind.conf includes it.
if [ -f "$ESP/EFI/refind/refind.conf" ] && ! grep -q "abzu.conf" "$ESP/EFI/refind/refind.conf"; then
    echo "include abzu.conf" >> "$ESP/EFI/refind/refind.conf"
fi

sync

echo
echo "=== Done ==="
echo "Reboot now. Hold the Option (Alt) key at the startup chime and pick"
echo "'EFI Boot' (it may take two tries on some firmwares). rEFInd should"
echo "show your Fedora/Abzu entry."
echo
echo "From inside Abzu later, keep the ESP current with:  just install-refind"
