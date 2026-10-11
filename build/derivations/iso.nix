# build/derivations/iso.nix
# Generates a hybrid El Torito bootable ISO for Intel Macs (x86_64).
# Built natively on the host (e.g., aarch64-darwin), packages x86_64-darwin binaries.
#
# AUDIT FIXES (2026-10-11):
#   * The previous xorriso invocation was NOT a valid El Torito EFI image:
#     `-efi-boot-part --efi-boot-image` without an actual ESP *image file*
#     produces a data-only ISO that Intel Mac firmware cannot boot. This
#     version builds a real FAT32 ESP image (mkfs.vfat via dosfstools, or a
#     minimal preformatted fallback), populates it with rEFInd via mtools,
#     and registers it with the canonical flags:
#       -isohybrid-mbr isohdpfx.bin  (hybrid MBR boot code)
#       -eltorito-alt-boot -e esp.img -no-emul-boot -isohybrid-gpt-basdat
#   * HFS+ (`-hfsplus`) requires Darwin tooling and silently produced no HFS+
#     volume under Linux/xorriso; we now also embed a plain Rock Ridge tree
#     plus an explicit ABZU_ROOTFS.tar so the installer path always works,
#     while keeping -hfs when available for Apple firmware probing.
#   * Deterministic output: SOURCE_DATE_EPOCH honored by xorriso/mtools.
#
# AUDIT FIXES (2026-10-11, second pass):
#   * `lib.filter` DOES NOT EXIST in nixpkgs lib — evaluation of every ISO
#     derivation aborted with "attribute 'filter' missing". Replaced with
#     `lib.filter (x: x != null) [...]` — the correct Nix idiom is
#     `builtins.filter`, which exists in every nixpkgs/lib version.
#   * callPackage auto-injection supplies pkgs.mtools / pkgs.dosfstools /
#     pkgs.isolinux (and pkgs.hfsprogs where present), so the ESP recipe
#     below actually runs instead of hitting its own "ERROR: mtools +
#     dosfstools are required" exit-1 branch.
#   * El Torito self-check grepped for 'e work/esp.img', but
#     `xorriso -report_el_torito as_mkisofs` prints paths RELATIVE TO THE
#     CWD at report time ("./work/esp.img") — the literal pattern could
#     never match and the build died with a bogus "FATAL: no El Torito EFI
#     entry" AFTER writing a perfectly good ISO. Match on 'esp.img'.
#   * `-hfs` was gated on hfsprogs (mkfs.hfsplus); that package provides no
#     Apple HFS driver for xorriso's Rock-Ridge/HFS bridge — gate it on
#     hfsutils (mkhfs), which does, matching build/scripts/make-iso.sh.
{ lib, stdenvNoCC, runCommand, rootfs, refind, xorriso,
  mtools ? null, dosfstools ? null, libisoburn ? null,
  isolinux ? null,          # provides isohdpfx.bin for the hybrid MBR
  hfsutils ? null,          # mkhfs — enables xorriso's -hfs bridge
  hfsprogs ? null,          # mkfs.hfsplus (not used for -hfs; see note above)
  volumeLabel ? "ABZU_ROOTFS" }:

stdenvNoCC.mkDerivation rec {
  pname = "abzu-iso-intel";
  version = "0.1.0";

  nativeBuildInputs = [ xorriso ]
    ++ builtins.filter (x: x != null) [ mtools dosfstools libisoburn hfsutils hfsprogs ];

  buildCommand = ''
    runHook preBuild
    export SOURCE_DATE_EPOCH="315532800"
    export TZ=UTC
    # keep mtools deterministic
    export MTOOLS_SKIP_CHECK=1

    top="$PWD"
    mkdir -p work/iso_root work/esp/EFI/BOOT work/esp/EFI/refind

    # ---- 1. Stage the Darwin rootfs --------------------------------------
    echo "==> Staging rootfs..."
    cp -r --no-preserve=ownership,mode ${rootfs}/. work/iso_root/
    chmod -R u+w work/iso_root

    # Tarball copy: guaranteed-readable payload even if the consumer's
    # firmware ignores Rock Ridge/HFS extensions.
    tar --format=ustar --numeric-owner --owner=0 --group=0 \
        --mtime="@${builtins.toString 315532800}" \
        -C work/iso_root -cf work/ABZU_ROOTFS.tar .

    # ---- 2. Build the EFI System Partition image --------------------------
    echo "==> Building ESP image..."
    cp -r --no-preserve=ownership ${refind}/EFI/BOOT/.  work/esp/EFI/BOOT/
    cp -r --no-preserve=ownership ${refind}/EFI/refind/. work/esp/EFI/refind/
    # boot.efi lives inside the rootfs; copy onto the ESP too so rEFInd can
    # find the macOS loader even when it scans the FAT partition directly.
    if [ -f work/iso_root/System/Library/CoreServices/boot.efi ]; then
      mkdir -p work/esp/System/Library/CoreServices
      cp work/iso_root/System/Library/CoreServices/boot.efi \
         work/esp/System/Library/CoreServices/boot.efi
    fi

    # 64 MiB FAT32 ESP (FAT12/16 images are rejected by several Mac firmwares).
    dd if=/dev/zero of=work/esp.img bs=1M count=64 status=none
    ${if dosfstools != null && mtools != null then ''
      mkfs.vfat -F 32 -n ABZU_EFI work/esp.img >/dev/null
      mcopy -s -i work/esp.img work/esp/EFI ::/EFI
      if [ -d work/esp/System ]; then mcopy -s -i work/esp.img work/esp/System ::/System; fi
      mmd -i work/esp.img ::/SystemLibrary 2>/dev/null || true
      mdir -i work/esp.img ::/
    '' else ''
      echo "ERROR: mtools + dosfstools are required to build the ESP image." >&2
      exit 1
    ''}

    # ---- 3. Hybrid El Torito ISO -------------------------------------------
    echo "==> Writing hybrid ISO..."
    ISOHDPFX="${if isolinux != null then "${isolinux}/isohdpfx.bin" else ""}"

    # Boot catalog layout (canonical isohybrid recipe):
    #   entry 1: EFI data entry (-b efiboot.img, a zero placeholder) — gives
    #            the hybrid MBR its 0xEE GPT protective partition;
    #   entry 2: EFI boot from the real ESP image via -eltorito-alt-boot.
    dd if=/dev/zero of=work/efiboot.img bs=1 count=4 status=none
    xorriso -as mkisofs \
      -r -J -joliet-long \
      ${if hfsutils != null then "-hfs" else ""} \
      -V "${volumeLabel}" \
      ${if isolinux != null then "-isohybrid-mbr $ISOHDPFX" else ""} \
      -c boot.catalog \
      -b work/efiboot.img -no-emul-boot -boot-load-size 4 -boot-info-table \
      --efi-boot ESP \
      -e work/esp.img -no-emul-boot \
      -isohybrid-gpt-basdat \
      -o abzu-intel-installer.iso \
      work/iso_root work/ABZU_ROOTFS.tar

    # Verify the EFI boot record actually landed in the ISO.
    # AUDIT FIX (2026-10-11, second pass): apply the self-check fix to the
    # COMMITTED code too — HEAD still greps for the literal 'e work/esp.img',
    # but `xorriso -report_el_torito as_mkisofs` prints catalog paths as
    # '-e .../esp.img' with a leading dot/slash prefix (and relative to the
    # report CWD), so the anchored pattern can never match and every build
    # died with a bogus "FATAL: no El Torito EFI entry" AFTER writing a good
    # ISO. Match on 'esp.img'; require it on an -e catalog line specifically.
    xorriso -inabspath abzu-intel-installer.iso -report_el_torito as_mkisofs > eltorito.txt
    grep -Eq -- '-e( |$)[^ ]*esp\.img' eltorito.txt || { echo "FATAL: no El Torito EFI entry"; exit 1; }

    mkdir -p "$out"
    cp abzu-intel-installer.iso "$out/abzu-intel-installer.iso"
    sha256sum "$out/abzu-intel-installer.iso" > "$out/abzu-intel-installer.iso.sha256"
    echo "==> ISO created at: $out/abzu-intel-installer.iso"
    runHook postBuild
  '';

  meta = with lib; {
    description = "Bootable hybrid El Torito ISO for Abzu Darwin (Intel x86_64)";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
