# gui/ — Abzu desktop: GNUstep core + GWorkspace shell + Aqua (Water/Light) theme

The Abzu GUI is a **GNUstep** environment (Foundation → AppKit/gnustep-gui →
GWorkspace windowed shell) running on top of Darwin's WindowServer-equivalent.
Three layers, built in order by `../build` (`nix build .#gui-theme` /
`make -C ../build gui`):

1. **gnustep-overlay/** — pinned GNUstep core sources + our patches:
   backend selection (X11-for-Mac fallback vs native CGS), font smoothing to
   match Aqua subpixel rendering, and the "Abzu" default user interface
   constants (corner radii, glass refraction indices).
2. **gworkspace-shell/** — GWorkspace configured as the login shell: dock
   ("*the Abyssolith*" — a nod to Abzu's Fedora predecessor; in-app it is
   simply the **Abzu Dock**), panels, file browsing with QuickLook-style
   previews.
3. **themes/abzu-aqua/** — the Water & Light theme: colour palette, widget
   imagery, caustics animations, sounds, cursors. This is what makes Abzu feel
   like *aqua as Sumer imagined it*: light refracting through deep water.

## Theme at a glance (`themes/abzu-aqua`)
- Palette: abyssal blues `#041E42` → `#0B6BA4`, surface cyan `#7FD8FF`,
  pearl highlight `#F4FBFF`, gold accent `#D9A441` (the "light" half).
- Widgets render with a thin specular top-edge ("meniscus") and animated
  caustic texture behind translucent panels.
- Sound set named after the Abzu myth cycle (see themes/abzu-aqua/SOUNDS.md).

## macOS app compatibility story
Because we expose GNUstep's ObjC runtime + Foundation with an API-compatible
shim layer (`NSApplication` lifecycle bridged into GWorkspace), a simple Cocoa
app rebuilt against our headers runs inside the same shell — the ravynOS
goal, achieved via GNUstep rather than closed-source frameworks. Complex apps
relying on private frameworks are out of scope for v1.
