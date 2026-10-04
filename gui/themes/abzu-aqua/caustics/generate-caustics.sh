#!/bin/sh
# generate-caustics.sh — procedurally render AbzuAqua caustic animation frames
# (light refracting through water) using awk math; writes binary PPM frames,
# then .tiff via netpbm pnmtotiff when available.
#
# Output: frameNNN.ppm / frameNNN.tiff next to this script
# Usage:  ./generate-caustics.sh [frames=8] [w=256] [h=64] [outdir=<script dir>]
set -eu
FRAMES="${1:-8}"; W="${2:-256}"; H="${3:-64}"
OUT="${4:-$(cd "$(dirname "$0")" && pwd)}"
mkdir -p "${OUT}"

awk -v F="${FRAMES}" -v W="${W}" -v H="${H}" -v OUT="${OUT}" 'BEGIN{
  pi = 3.14159265358979;
  for (f = 0; f < F; f++) {
    fn = sprintf("%s/frame%03d.ppm", OUT, f);
    printf "P6\n%d %d\n255\n", W, H > fn;
    ph = 2 * pi * f / F;
    for (y = 0; y < H; y++) for (x = 0; x < W; x++) {
      # three travelling sine bands = cheap caustic interference pattern
      v = (sin(x*0.09 + ph) + sin((x+y)*0.05 - ph*1.3) + sin(y*0.13 + ph*0.7)) / 3.0;
      g = (v > 0 ? v : 0);                       # light rides the crests only
      r = int(4   + 60  * g);                    # abyssal blue base (#041E42-ish)
      gr = int(30 + 160 * g);                    # cyan rise
      b = int(66  + 189 * g);                    # toward surface cyan #7FD8FF
      if (r > 255) r = 255; if (gr > 255) gr = 255; if (b > 255) b = 255;
      printf("%c%c%c", r, gr, b) > fn;
    }
    close(fn);
  }
}'

if command -V pnmtotiff >/dev/null 2>&1; then
  for p in "${OUT}"/frame*.ppm; do pnmtotiff "$p" > "${p%.ppm}.tiff"; done
fi
echo "==> wrote ${FRAMES} caustic frame(s) (${W}x${H}) into ${OUT}"
