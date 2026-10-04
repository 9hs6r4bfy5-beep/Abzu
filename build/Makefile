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
SHELL := /bin/sh
ARCH  ?= x86_64
ISO   ?= abzu-$(ARCH)-0.1.0.iso
STAGE := $(CURDIR)/staging
DIST  := $(CURDIR)/distfiles
SCRIPTS := $(CURDIR)/scripts

.PHONY: all fetch kernel userland gui packages rootfs iso clean check
all: iso

fetch:
	../userland/build-openbsd-tools.sh fetch
	$(SCRIPTS)/fetch-distfiles.sh "$(DIST)"

kernel:
	cd ../kernel && ./build-xnu.sh $(ARCH) Release DST_ROOT=$(STAGE)

userland:
	DIST=$(DIST) OUT=$(STAGE) ../userland/build-openbsd-tools.sh all

gui:
	STAGE=$(STAGE) ../gui/build-gui.sh

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
