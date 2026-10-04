# userland/mach_compat — Darwin/Mach-O shims for OpenBSD sources

Small, per-tool patches applied by `../build-openbsd-tools.sh` before compiling
OpenBSD `-current` sources as Mach-O against Darwin system headers. Keep each
patch under ~50 lines; anything larger belongs upstream (OpenBSD) or in a
generated configure override.

## Common collision classes handled here
- `__COPYRIGHT(c)` / `SCCSIDS` macros: defined away via `-D__COPYRIGHT\(c\)=`.
- `<sys/param.h>` MAXMIN & roundups: prefer Darwin's; shim undefs duplicates.
- `strlcpy/strlcat`: already present in Darwin libSystem since 10.7 → patch
  removes OpenBSD's static copies to avoid symbol clashes.
- `pledge()` / `unveil()`: **no-op compat stubs** provided by `abzu-compat.c`
  (real enforcement is planned via XNU patch 0002 + sandbox(7) profiles; until
  then tools compile unchanged and the stubs return 0).
- `arc4random*`: Darwin libSystem provides them; shim deletes OpenBSD's
  `kern/arandom.c` from the fileset.
- `endian.h` vs `<machine/endian.h>`: force Darwin spelling.
- rc.conf/rc integration: replaced by launchd job generation at ISO build time
  (see ../../build/scripts/assemble-rootfs.sh).

## Files
| name | applies to | purpose |
|---|---|---|
| `abzu-compat.c` | any tool | pledge/unveil/explicit_bzero fallback symbols |
| `doas.patch` | usr.bin/doas | PAM-less auth path + setuid handling on APFS volumes |
| `ksh.patch` | usr.bin/ksh | disable tty raw-mode ioctl spelling that differs on Darwin |
