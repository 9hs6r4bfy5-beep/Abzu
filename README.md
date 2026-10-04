# Abzu (Darwin × OpenBSD × GNUstep)

**Abzu** (Sumerian: 𒀊𒍪, *the deep / primordial freshwater sea*) is the
flagship edition of the Abzu operating system: a custom OS built on
**Apple's Darwin** open-source core (XNU +
userland releases from [opensource.apple.com](https://opensource.apple.com/releases/))
with an **OpenBSD** userland filling in the blanks, and a **GNUstep** desktop
painted in a bespoke **"Aqua" theme inspired by Water and Light**.

> **Naming:** "Abzu Abyssolith" refers to the *previous* Fedora-based
> Universal Blue / BlueBuild edition of Abzu
> ([Abzu-Abyssolith](https://github.com/9hs6r4bfy5-beep/Abzu-Abyssolith)).
> This Darwin-based repository is simply **Abzu** — the flagship version
> going forward. The Fedora/BlueBuild Abyssolith remains as a historical
> counterpart; feature parity with it ("functionally the same") is a goal here.

Inspired by prior efforts — [OpenDarwin](https://archiveos.org/opendarwin/),
[PureDarwin](https://puredarwin.org/), and [ravynOS](https://ravynos.com/) —
Abzu aims to be *functionally* the same OS as its Fedora (Abyssolith)
counterpart: extremely
secure, easy to use, aesthetics-first, and equally at home as a **desktop**,
**gaming rig**, **workstation**, and **homelab** node. Unlike ravynOS (which
fills gaps with FreeBSD), Abzu fills them with **OpenBSD** — W^X, pledge/unveil,
unrivalled audit culture — layered under Mach/BSD hybrid machinery.

> **Status: early bring-up.** This repository scaffolds the build system for a
> bootable ISO targeting Intel Macs first (Mach-O, EFI via rEFInd/OpenCore),
> with PowerPC (32-bit NewWorld/OldWorld), ARM64 (Apple Silicon toolchain
> path), and the wider OpenBSD architecture family (amd64/i386/arm64/ppc64/…)
> tracked as stretch goals.

---

## Design pillars

1. **Security by construction** — OpenBSD userland (`libc`, `sh`, `ssh`,
   `sudo`-free `doas`, unveil'd daemons) over hardened XNU; no proprietary
   blobs required for base boot.
2. **Water & Light ("Aqua")** — GNUstep-based shell with translucent,
   caustic-lit widgets; theme assets live in [`gui/themes/abzu-aqua`](gui/themes/abzu-aqua).
3. **macOS app compatibility** — Mach-O ABI + Objective-C runtime parity means
   a Cocoa app can be rebuilt/ported to Abzu with minimal changes (see
   [`kernel/patches`](kernel/patches) and [`userland/mach_compat`](userland/mach_compat)).
4. **History preservation** — curated archives of Apple Computer, video game,
   and Sumerian/Mesopotamian heritage ship preinstalled
   ([`packages/history-archives`](packages/history-archives)).
5. **Reproducible builds** — everything assembled by Nix flakes (primary) or
   plain Makefiles (fallback) into a single bootable ISO
   ([`build/`](build)).

## Repository layout

| Directory | Contents |
|---|---|
| [`kernel/`](kernel) | XNU build scripts and minimal patches (apple/xnu ~6574.141.x era baseline) |
| [`userland/`](userland) | OpenBSD userland tools compiled for Darwin (Mach-O ports + import manifests) |
| [`gui/`](gui) | GNUstep core overlays, GWorkspace shell, custom "Aqua" (Water/Light) theme assets |
| [`packages/`](packages) | Preinstalled software: emulators, history archives, homelab tools |
| [`build/`](build) | Nix flake + Makefile scripts to assemble the bootable ISO |

## Quick start

```sh
# Reproducible (recommended): Nix with the Darwin overlay
cd build && nix flake check                      # validate inputs
nix build .#iso-intel                            # → result: bootable ISO (Intel Mac target)
nix build .#xnu-kernel                           # kernel only
nix build .#gui-theme                            # GNUstep + Aqua theme bundle

# Fallback: staged Makefile pipeline
make -C build fetch                              # vendor tarballs into build/distfiles/
make -C build kernel                             # patch + build XNU (needs macOS/Darwin host)
make -C build userland                           # OpenBSD→Mach-O cross stage
make -C build gui                                # GNUstep core + GWorkspace + theme
make -C build iso                                # assemble abzu-<arch>-0.1.0.iso
```

See [`build/README.md`](build/README.md) for host requirements and
[`docs/ROADMAP.md`](docs/ROADMAP.md) for the bring-up order.

## Legal

Source-level work in this repository is MIT-licensed (see [`LICENSE`](LICENSE)).
Upstream components remain under their own licences: APSL 2.0 (Apple/Darwin),
BSD-2/BSD-3-style (OpenBSD, GNUstep). Trademarks belong to their owners; this
is an independent, non-affiliated project. See [`docs/LICENSES.md`](docs/LICENSES.md).
