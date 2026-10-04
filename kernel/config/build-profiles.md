# kernel/config — build profiles

Abzu ships three kernel build profiles, consumed by `build-xnu.sh` and the
Nix flake (`../build/flake.nix`, attr `xnu-kernel-<profile>`):

## release (default)
- `KERNEL_CONFIGS=Release`, stripped, no KextDebug, no panic-on-warn.
- SIP-equivalent policy compiled in: restricted kext loading, signed root on
  data volume where the volume format supports it.
- `security.abzu_wx=1` (patch 0002) enforced by default; boot-arg
  `abzu_wx=0` only honoured when booted in Developer mode.

## debug
- Kernel with KASLR disabled for symbolication parity, DTrace enabled,
  IOKit leak checker on. Never ship in ISOs.

## development
- Release + verbose boot + serial console on Macs that expose one
  (`chosen` node), plus the Abzu "lighthouse" early-boot splash hook used by
  ../gui/themes/abzu-aqua (boot logo = light through water).

## Boot arguments (release ISO default)
```
keepsyms=0 abzu_wx=1 cluster_log_level=3 -wegoff
```
(`-wegoff` disables WebContent GPU process until our GNUstep WebView lands; see
docs/ROADMAP.md.)

## Architecture matrix
| arch | status | notes |
|---|---|---|
| x86_64 | **primary** | Intel Macs 2007+; EFI boot via rEFInd stub |
| i386   | frozen    | 32-bit EFI Macs (2006); best-effort, no GUI accel |
| arm64  | research  | Asahi-derived toolchain path; no Apple Silicon firmware OSS yet |
| ppc    | research  | NewWorld (G4/G5) OpenFirmware boot; needs cross ldm |
