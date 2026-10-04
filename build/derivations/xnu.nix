# xnu.nix — compile Apple's open-source XNU into a bootable Mach-O kernel.
#
# Reality check (same constraint PureDarwin documents): XNU emits Mach-O and
# needs a Darwin host toolchain (clang targeting x86_64-apple-darwin, ld64,
# apple-libtool, Mach-O system headers). This derivation therefore supports
# three build paths, selected automatically:
#
#   1. Native Darwin builder (macOS host, or a darwin-nix remote builder):
#      plain `make ARCH_CONFIGS=x86_64 KERNEL_CONFIGS=Release`.
#
#   2. Darwin-in-container on Linux hosts (NIX_XNU_USE_CONTAINER=1, requires
#      docker + a Darwin-OS image such as the one the PureDarwin/ravyn-style
#      Nix work builds on, e.g. ghcr.io/lnl-swe/darwin-os). The hashed source
#      tree is bind-mounted; the identical make invocation runs inside.
#
#   3. Cross-toolchain on Linux (NIX_XNU_CROSS_TOOLCHAIN=<dir>): best-effort
#      path for an x86_64-apple-darwin clang/libtool collection from the
#      darwin-nix overlay.
#
# If none apply we fail loudly with remediation text — we never emit a fake
# "kernel". An ISO without a genuine kernel.macho is flagged downstream as
# installer-skeleton (see scripts/assemble-rootfs.sh).
#
# Output layout (consumed by rootfs.nix / assemble-rootfs.sh):
#   $out/System/Library/Kernels/kernel     Mach-O x86_64 kernel
#   $out/bootstrap/<arch>/                 libsa / KPI bootstrap artifacts
#   $out/nix-support/kernel-macho          path to the installed kernel
#   $out/var/db/abzu/build.json            provenance record
{ lib, stdenvNoCC, runCommand, fetchzip, git, file, srcInfo
, patches ? ../../kernel/patches }:

let
  arch   = "x86_64";
  config = "Release";

  sources = import ./xnu-sources.nix {
    inherit stdenvNoCC runCommand fetchzip git srcInfo;
  };
in stdenvNoCC.mkDerivation rec {
  pname = "abzu-xnu";
  version = srcInfo.xnuTag;

  inherit sources arch config;
  patchList = patches;

  nativeBuildInputs = [ git file ];

  dontConfigure = true;

  phases = [ "unpackPhase" "patchPhase" "buildPhase" "installPhase" ];

  unpackPhase = ''
    echo "==> unpacking XNU ${srcInfo.xnuTag} (+ APSL companions)"
    mkdir -p work && cd work
    cp -r --preserve=mode,timestamps ${sources}/* .
    chmod -R u+w .
    cd ..
    sourceRoot = work/xnu
  '';

  patchPhase = ''
    runHook prePatch
    cd "$sourceRoot"
    applied=0
    for p in ${patchList}/*.patch; do
      [ -e "$p" ] || continue
      name=$(basename "$p")
      if git apply --check "$p" 2>/dev/null; then
        echo "==> applying $name"; git apply "$p"; applied=$((applied+1))
      elif git apply --check -3 "$p" 2>/dev/null; then
        echo "==> applying $name (three-way)"; git apply -3 "$p"; applied=$((applied+1))
      else
        echo "==> skipping $name (not applicable to ${srcInfo.xnuTag})"
      fi
    done
    echo "==> $applied Abzu patch(es) applied"
    runHook postPatch
  '';

  buildPhase = ''
    runHook preBuild
    cd "$sourceRoot"
    JOBS="''${NIX_BUILD_CORES:-$(nproc)}"
    MAKE_ARGS=(ARCH_CONFIGS="$arch" KERNEL_CONFIGS="$config"
               ALL_BUILD_VERSION_STRING=Abzu BUILD_STRIPLIT_MASK=16)

    if [ "$(uname -s)" = "Darwin" ]; then
      # ---- path 1: native Darwin builder -----------------------------------
      echo "==> building XNU natively on Darwin ($JOBS jobs)"
      make -j"$JOBS" "''${MAKE_ARGS[@]}" || exit 1

    elif [ -n "''${NIX_XNU_USE_CONTAINER:-}" ] && command -v docker >/dev/null; then
      # ---- path 2: Darwin OS container on a Linux host ----------------------
      IMAGE="''${NIX_DARWIN_IMAGE:-ghcr.io/lnl-swe/darwin-os:latest}"
      HOST_SRC="$(cd ../.. && pwd)"     # the whole `work/` tree, host-side
      echo "==> building XNU inside Darwin container $IMAGE"
      docker run --rm \
        -v "$HOST_SRC:/abzu-src:rw" -w /abzu-src/xnu \
        "$IMAGE" \
        sh -c 'make -j'"$JOBS"' ARCH_CONFIGS='"$arch"' KERNEL_CONFIGS='"$config"' \
              ALL_BUILD_VERSION_STRING=Abzu BUILD_STRIPLIT_MASK=16' || exit 1

    elif [ -n "''${NIX_XNU_CROSS_TOOLCHAIN:-}" ]; then
      # ---- path 3: cross toolchain (best effort) ----------------------------
      TC="$NIX_XNU_CROSS_TOOLCHAIN"
      [ -d "$TC" ] || { echo "!! NIX_XNU_CROSS_TOOLCHAIN=$TC not a directory"; exit 1; }
      export PATH="$TC/bin:$PATH" CC="$TC/bin/clang" LIBTOOL="$TC/bin/libtool"
      echo "==> cross-building XNU with toolchain at $TC"
      make -j"$JOBS" "''${MAKE_ARGS[@]}" || exit 1

    else
      cat >&2 <<'EOF'
*******************************************************************
!! XNU produces a Mach-O kernel and needs a Darwin toolchain.
!! No Darwin builder, container, or cross-toolchain was selected.
!! Pick one:
!!   nix build .#xnu-kernel                       # on a Darwin builder
!!                                                    (darwin-nix remote builder)
!!   NIX_XNU_USE_CONTAINER=1 nix build .#xnu-kernel --impure \
!!        --option sandbox false                  # Darwin-OS docker image
!!   NIX_XNU_CROSS_TOOLCHAIN=... nix build .#xnu-kernel
!!   ../kernel/build-xnu.sh x86_64 Release        # directly on an Intel Mac
*******************************************************************
EOF
      exit 1
    fi
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    dst="$out/System/Library/Kernels"
    mkdir -p "$dst" "$out/nix-support" "$out/bootstrap/${arch}" "$out/var/db/abzu"

    kern=""
    for cand in \
        "build/''${config}.EQUIV/kernel.''${arch}" \
        "build/Kernel_''${config}/kernel.''${arch}" \
        "BUILD/obj/kernel.''${arch}"; do
      if [ -f "$cand" ]; then kern="$cand"; break; fi
    done
    [ -n "$kern" ] || { echo "!! kernel mach-o not found under build/ — inspect XNU build layout"; exit 1; }

    file "$kern" | grep -q "Mach-O.*x86_64" \
      || { echo "!! $kern is not a Mach-O x86_64 binary: $(file "$kern")"; exit 1; }

    install -m644 "$kern" "$dst/kernel"
    echo "$dst/kernel" > "$out/nix-support/kernel-macho"

    # KPI bootstrap artifacts kext/userland SDK derivations consume later.
    for d in BOOT/library_bootstrap_''${arch} libsa libkern; do
      [ -d "BUILD/obj/$d" ] && cp -r "BUILD/obj/$d" "$out/bootstrap/''${arch}/" || true
    done

    cat > "$out/var/db/abzu/build.json" <<JSON
{
  "project": "abzu",
  "component": "xnu",
  "tag": "${srcInfo.xnuTag}",
  "rev": "${srcInfo.xnuRev}",
  "arch": "${arch}",
  "config": "${config}",
  "license": "APSL-2.0"
}
JSON
    runHook postInstall
  '';

  meta = with lib; {
    description = "Abzu XNU kernel (${srcInfo.xnuTag}, ${arch}/${config})";
    license = licenses.free;   # upstream: Apple APSL 2.0
    platforms = platforms.all; # build-path selection happens inside buildPhase
  };
}
