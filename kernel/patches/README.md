# Abzu minimal XNU patch set

Philosophy (inherited from PureDarwin/OpenDarwin practice): **every** delta to
apple-oss-distributions/xnu must be small, single-purpose, and rebaseable onto
new release tags without manual surgery. If a change can live in userland or
in a kext, it does.

Rules:
1. Numbered `NNNN-abzu-*.patch`, plain `git apply` compatible.
2. No cosmetic reformatting; no vendored code removal.
3. Each patch gets a one-line entry below plus a tracking issue.

| Patch | Purpose | Rebase risk |
|---|---|---|
| 0001 | Stamp "Abzu" into the kernel version string | trivial |
| 0002 | `security.abzu_wx` knob: OpenBSD-style W^X on user mappings | low |
| 0003 | GNUstep/GWorkspace WindowServer hints: allow third-party window decorations via CGS private hook stubs | medium (private API drift) |

Planned but **not yet applied** (tracked in docs/ROADMAP.md):
- PowerPC (`ppc`) config revival for NewWorld Macs — needs an ldm/Mach-O ppc
  toolchain; blocked on a maintained powerpc-apple-darwin cross-compiler.
- IOKit registry seed for rEFInd-based boot on 2006–2012 Intel Macs
  (EFI 1.x quirks).

## Verifying patches against a tag

```sh
cd "$(mktemp -d)" && git clone --depth 1 --branch xnu-11417.101.15 \
  https://github.com/apple-oss-distributions/xnu.git xnu
for p in /path/to/kernel/patches/*.patch; do
  git -C xnu apply --check --verbose "$p" || echo "FAIL: $p"
done
```

Line offsets are intentionally fuzzy (`@@ -XX,X`) — apply with `git apply -3`
(three-way merge) when fuzz fails, then re-roll the patch with
`git format-patch`.
