# build/Makefile — staged ISO pipeline (fallback when Nix is unavailable)
#
#   make fetch     vendor OpenBSD src.tar.gz + GNUstep + Darwin indices
#   make kernel    XNU via ../kernel/build-xnu.sh      (Darwin host required)
#   make userland  OpenBSD→Mach-O tools via ../userland/build-openbsd-tools.sh
#   make gui       GNUstep core + GWorkspace + AbzuAqua theme
#   make packages  resolve & verify packages/* manifests
#   make rootfs    assemble staging/ into a Darwin-shaped root filesystem
#   make iso       hybrid HFS+/FAT+El Torito ISO with rEFInd EFI boot
#   make clean     drop staging/, keep distfiles cache
#
# Primary/reproducible path remains: nix build .#iso-intel (see flake.nix).
#
# AUDIT FIXES (2026-10-11):
#   * DISTFILE PATH MISMATCH: `make fetch` stored distfiles under
#     build/distfiles ($(DIST)), but ../userland/build-openbsd-tools.sh and
#     the rEFInd/GNUstep fetchers read from repo-root ./distfiles. The two
#     "make fetch" / "make userland" halves therefore never saw each other's
#     downloads and `make userland` failed on a fresh clone. DIST now points
#     at the single canonical location used by every script; override with
#     `make DIST=/some/path ...`.
#   * KERNEL stage honours ABZU_KERNEL_PATH (Catalina mach_kernel copied off
#     the user's install) so `make iso` can complete without an Apple SDK.
SHELL := /bin/sh
ARCH  ?= x86_64
ISO   ?= abzu-$(ARCH)-0.1.0.iso
REPO  := $(abspath $(CURDIR)/..)
STAGE := $(CURDIR)/staging
# Canonical distfile cache shared by fetch-distfiles.sh, the userland
# builder, and the GUI fetcher (was: $(CURDIR)/distfiles — invisible to them).
DIST  ?= $(REPO)/distfiles
SCRIPTS := $(CURDIR)/scripts
# Pre-compiled Catalina kernel (MODE A). Required for `make iso` on non-Darwin
# hosts; leave unset on Intel Macs that compile XNU natively.
ABZU_KERNEL_PATH ?=

.PHONY: all fetch kernel userland gui packages rootfs iso clean check
all: iso

fetch:
	../userland/build-openbsd-tools.sh fetch
	$(SCRIPTS)/fetch-distfiles.sh "$(DIST)"

kernel:
ifeq ($(strip $(ABZU_KERNEL_PATH)),)
	cd ../kernel && ./build-xnu.sh $(ARCH) Release DST_ROOT=$(STAGE)
else
	@echo "==> staging pre-compiled kernel from $(ABZU_KERNEL_PATH)"
	mkdir -p $(STAGE)/System/Library/Kernels
	install -m644 $(ABZU_KERNEL_PATH) $(STAGE)/System/Library/Kernels/kernel
endif

userland:
	DIST=$(DIST) OUT=$(STAGE) ../userland/build-openbsd-tools.sh all

gui:
	STAGE=$(STAGE) DIST=$(DIST) ../gui/build-gui.sh

packages:
	$(SCRIPTS)/verify-packages.sh ../packages
	$(SCRIPTS)/fetch-packages.sh ../packages "$(STAGE)"

rootfs: kernel userland gui packages
	$(SCRIPTS)/assemble-rootfs.sh "$(STAGE)"

iso: rootfs
	$(SCRIPTS)/make-iso.sh "$(STAGE)" "$(ISO)"
	@echo "==> wrote $(ISO)"
	@shasum -a 256 "$(ISO)" 2>/dev/null || sha256sum "$(ISO)"

check:
	nix flake check

clean:
	rm -rf $(STAGE) $(ISO)
