# AbzuAqua theme assets

Vector masters live in `masters/` (SVG); rendered TIFF/PNG sets are produced by
`../build-gui.sh` via `inkscape --export-type=tiff`. Do not commit regenerated
binaries larger than 200 KB — build them instead.

## Naming convention
`<widget>-<motif>.tiff`, motifs drawn from the Water & Light vocabulary:
| motif | meaning | used for |
|---|---|---|
| puddle | shallow reflected light | default buttons |
| abzu | deep well, dark core | prominent/default action |
| reed | flexible vertical | sliders, splitters |
| tide | horizontal motion | progress bars |
| clay | cuneiform tablet texture | scrollbars, list rows |
| meniscus | surface tension line | window top edge |
| lighthouse | first light above water | boot splash, alerts |

## Required files (checked by CI `theme-lint`)
- button-puddle.tiff, button-abzu.tiff
- slider-reed.tiff, progress-tide.tiff, scroll-clay.tiff
- pointer-otter.tiff (cursor), selection-caustic.tiff
- sounds/{tidal-bell,abzu-rising,enki-storm,silt-settle}.aiff

## Licensing note
All artwork here is original Abzu project work under the repo MIT licence;
*inspired by* Aqua aesthetics only — no Apple assets may be committed.
