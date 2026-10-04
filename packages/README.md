# packages/ — curated preinstalled software for the Abzu ISO

Everything here is *declarative*: manifests listing what ships, with fetch &
verification handled by `../build` (Nix prefers fixed-output derivations; the
Makefile fallback uses `fetch.sh`). Three shelves:

## emulators/ — "The Chariots of Nammu" (gaming pillar)
Preserving video-game history = running it. RetroArch cores + standalone
emulators, all FOSS, bundled with BIOS-free defaults and a legal note on ROMs.

## history-archives/ — Apple, games & Sumer, offline-first
Static, indexable collections rendered by the preinstalled `mandoc`/browser:
- **Apple Computer history**: opensource.apple.com release metadata, Darwin
  timeline, scanned-era documentation we may legally mirror (project Gutenberg
  style link-outs where full text can't be vendored).
- **Video game history**: console/game chronologies, manual mirrors from
  archive.org items with clear provenance fields.
- **Sumerian history**: ETCSL text corpus access, cuneiform sign charts
  (Unicode 𒀀 range fonts), Abzu myth cycle audio book placeholders.

Provenance rules: every entry in `manifest.json` must carry `source`,
`license`, and `provenance` before it can enter an ISO build (`build/scripts/
verify-packages.sh` fails the build otherwise).

## homelab/ — the workstation/server pillar
doas-hardened services with launchd plists generated at assemble time:
OpenSSH (-current from ../userland), unbound, rsync backup agent, restic,
podman-compatible container runtime stub (Darwin kernel limitation noted),
plus `abzu-firewall` (application-layer front-end over XNU netinfo replacing
pfctl — see ../../userland/import/skip.txt).
