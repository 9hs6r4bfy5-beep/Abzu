# gui/gnustep-overlay — our deltas on GNUstep core

Pinned upstream versions (verified against gnustep.org releases):

| component | version | role |
|---|---|---|
| gnustep-make | 2.9.2 | build system |
| gnustep-base | 1.31.1 | Foundation (NS* classes) |
| gnustep-gui  | 0.32.0  | AppKit equivalent |
| gnustep-back | 0.32.0  | backend (X11 for bring-up; native CGS target) |
| GWorkspace   | 1.1.0   | desktop shell |

Overlay patches (`patches/`, applied by ../build-gui.sh and the Nix `gui-core`
derivation via `postPatch`):

- `0001-font-smoothing.patch` — map `-GAFontAntialiasing` defaults so text
  matches Aqua-style subpixel rendering out of the box.
- `0002-theme-search-path.patch` — add `/System/Library/Themes` and
  `/Library/Themes/AbzuAqua.theme` to theme lookup before user dirs.
- `0003-caustics-compositor.patch` — hook `NSWindow` background draw to blit
  the animated caustic layer from AbzuAqua.theme when `Caustics.Enabled`.
- `0004-doas-auth.patch` — route GNUstep authorization dialogs through
  `doas(1)` instead of sudo askpass (security pillar).

All four are intentionally tiny; upstreaming is tracked per-patch in
../../docs/ROADMAP.md.
