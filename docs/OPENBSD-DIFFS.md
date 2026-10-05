# OpenBSD userland → Abzu (Darwin/XNU): the relevant differences

Take-stock document for the port. Companion to [`ROADMAP.md`](ROADMAP.md), which
turns these findings into sequenced work. Findings were checked against the tree
in this repo (`userland/`, `build/derivations/openbsd-userland.nix`,
`kernel/patches/`) plus upstream OpenBSD 7.6 and Apple OSS sources.

Abzu's pillars are *extremely secure* and *quality of life*. OpenBSD is where
both come from, so the port order is: **security primitives first, then the QoL
tools that depend on them.**

---

## A. What already exists here (and its state)

| Asset | Location | State |
|---|---|---|
| Import driver (fetch → port → stage) | `userland/build-openbsd-tools.sh` | Skeleton; gaps enumerated in §E |
| Tool manifest (18 rows) | `userland/import/tools.manifest` | Ambiguous format for multi-word rows (§E1) |
| Kernel-coupled skip list | `userland/import/skip.txt` | Sound; missing `authpf`, `ftp-proxy`, `skey` |
| Compat stubs | `userland/mach_compat/abzu-compat.c` | `pledge()`/`unveil()` **return 0 and do nothing** — security cliff (§B1) |
| Shim docs | `userland/mach_compat/README.md` | Good taxonomy; references `doas.patch` + `ksh.patch` that **do not exist** |
| `/etc` overlay | `userland/etc/{doas.conf,master.passwd}` | No `login.conf`, no motd, no rc.d parity, no sandbox profiles (§B3, §C1) |
| W^X knob | `kernel/patches/0002-openbsd-wx-enforcement.patch` | Fuzzy hunks; `CTLFLAG_KERNSEC` is not a real XNU flag; unverified vs `xnu-7195.141.2` |
| launchd generation | `build/scripts/assemble-rootfs.sh`, `build/derivations/rootfs.nix` | Emits plists pointing at `/etc/sandbox.d/abzu-services.sb`, **which is never shipped** |

## B. Security-domain differences

### B1. Privilege reduction: `pledge(2)` / `unveil(2)`

| | OpenBSD | Darwin/XNU |
|---|---|---|
| syscall | `pledge(paths, promises)`, `unveil(path, perm)` | none |
| granularity | per-process, irreversible promise mask (`stdio rpath wpath exec inet pfsock dns recvfd proc …`) | Seatbelt `.sb` profile applied via `sandbox_init(3)`/`sandbox-exec(1)`; coarse, exec-time |
| introspection | `ps -O pledge` | none |
| headers/link | `<unistd.h>`, libc | `<sandbox.h>`, `-lsandbox`; availability gated by `TARGET_OS_SANDBOX` in `<TargetConditionals.h>` |

**Consequence:** every imported tool calling `pledge("stdio rpath")` currently
believes it is sandboxed and is not. Silent success is worse than failing closed.

**Two-phase approach**
1. *Now (userland):* translate the promise string into a generated seatbelt
   profile and call `sandbox_init(3)`. On translation failure honour
   `ABZU_PLEDGE=fail|warn|off` — default **fail** for daemons, **warn** during the
   enablement window. Mapping table: `userland/security/pledge-map.tsv`.
2. *Later (kernel, patch 0003):* store the promise mask on `struct proc` in
   `bsd/kern` and enforce at `open`/`exec`/`socket`/`ioctl` — true OpenBSD
   semantics, irreversible narrowing, visible in `ps`.

`unveil()` maps directly onto `(allow file-read* (subpath "/…"))` rules; the
per-tool path sets live in each tool's sandbox profile.

### B2. W^X and memory discipline

| | OpenBSD | Darwin/XNU |
|---|---|---|
| mmap W+X | refused for unprivileged procs (6.3+) | allowed unless hardened runtime or patch 0002 |
| malloc hardening | `malloc_conceal`, guard pages, junk alloc | libmalloc guards only under env vars |
| stack canaries | `-fstack-protector-strong` by default in base | opt-in |
| RELRO | `-Wl,-z,now` default | n/a (Mach-O); equivalent = dyld binding + zero late GOT writes |
| ASLR/KASLR | forced | forced for PIE since 10.14; KASLR boot-arg controlled |

**Approach:** keep exactly one kernel hook (patch 0002, corrected spelling of
`SYSCTL_PROC`/`OID_AUTO`, drop the invented CTLFLAG) and add the userland half:
`userland/config/abzu.mk.inc` injecting
`-fstack-protector-strong -D_FORTIFY_SOURCE=2 -pipe -O2` and stripping ELF-only
`-Wl,-z,*` flags clang rejects for Mach-O targets.

### B3. Authentication & privilege: `doas` vs `sudo`

| | OpenBSD | Darwin (our target) |
|---|---|---|
| elevation config | `doas.conf` — small, auditable | we ship it and delete sudo ✔ |
| passwd db | `/etc/master.passwd` + `pwd.db` (Berkeley DB, 0600) | same names, but macOS expects OpenDirectory → run `pwd_mkdb -p` at first boot |
| hash algorithm | bcrypt (`crypt_blowfish`) in libc | Darwin `crypt(3)` historically DES/MD5 → `$2b$` hashes will **not** verify unless we link blowfish |
| PAM | deliberately absent | present; doas' `#ifdef HAVE_LIBUTIL`/PAM paths must be compiled out |
| tty ownership | `/dev/ttyp*` group `tty`, `CWGROUP=tty` | needs an `abzu-init` step or doas' prompt-safety checks misbehave |
| root | password-enabled | locked (`*LK*`); all elevation via `:wheel` + doas ✔ |

**Approach:** ship `userland/etc/login.conf` (trimmed capability DB with the
`default`/`daemon`/`auth` classes our tools query), force bcrypt in the
first-boot wizard, and add `mach_compat/doas.patch`: disable PAM, use
`getpeereid(3)` for the persist check, read `/etc/login.conf`, install setuid
with explicit mode on APFS.

### B4. Network filter: the `pf` family

`pfctl`, `ftp-proxy`, `authpf`, `relayd`'s anchor layer ride the `/dev/pf` ioctl
ABI, which XNU lacks — correctly skipped today. Additions: import `unbound`
(not the kernel-hooked `unwind`), and make `abzu-firewall` genuinely fail-closed:
if no backend exists, write `/etc/abzu/firewall.pending` and refuse to start
services flagged `requires-firewall` instead of merely noting it.

### B5. libc semantics

| symbol | Darwin libSystem | action |
|---|---|---|
| `arc4random*`, `reallocarray`, `strlcpy/strlcat`, `explicit_bzero`, `readpassphrase`, `err/warn` | present (10.7–12.0 as noted) | delete OpenBSD copies; gate stubs on `__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__` |
| `timingsafe_bcmp/timingsafe_memcmp` | **absent** | compat implementation (used by doas, ssh, tar) |
| `recallocarray` | absent | compat |
| `pledge/unveil` | absent | see §B1 |
| syslog facility numbering | slightly different | map when generating `/etc/syslog.conf` |

### B6. Filesystem & permission semantics

* SUID/SGID honoured on HFS+/APFS but stripped by some install paths → install
  explicitly (`passwd`, `ping`) and review each: prefer doas + narrow profile.
* `/tmp` sticky bit handled by `assemble-rootfs.sh` ✔.
* Case-**insensitive** HFS+ breaks `mandoc` and `sqlite3` collations. fstab
  currently says plain `hfsfs` → recorded as risk R-Q3 (build root case-sensitive).

## C. Quality-of-life domain differences

### C1. Init/services: `rc.conf` + `/etc/rc.d` vs `launchd`

OpenBSD exposes ~120 `/etc/rc.d` scripts toggled by two lines in
`rc.conf.local` — a big part of its QoL. Darwin uses plist jobs. We generate
plists from the homelab manifest, but there is no per-tool daemon toggle and the
referenced sandbox profile doesn't exist. Fix: one declarative source of truth,
`userland/etc/rc.d.tsv` (tool → launchd label → default state → sandbox profile →
privdrop user), consumed by **both** `assemble-rootfs.sh` and the Nix derivation,
plus real profiles in `userland/etc/sandbox.d/`. That gives `abzu-ctl enable ntpd`
a single backing table.

### C2. Shell & console

* `/bin/sh` → ksh(1): right call (also keeps GPLv3 bash out of base, §D); needs
  the referenced-but-missing `ksh.patch` (termios spelling, `TIOCGWINSZ`).
* `login(1)` skipped (correct): first boot chains `abzu-init → getty →
  login.apple → doas`.
* `motd`: OpenBSD regenerates it at boot; ship `etc/motd` + refresh hook.
* `TERM=sun`/wscons assumptions in `vi`/`tmux`: default to `xterm-256color` via
  `login.conf`.

### C3. Documentation toolchain

`mandoc`/`man` is the highest-value pure-userland QoL import (it renders the
OpenBSD man corpus that makes these ports legible). Promote to tier 1; point
`makewhatis` at `/var/db/man`.

### C4. Integrity & packaging

`pkg_add` stays skipped (signature DB + `wsyncd` are OpenBSD-specific), but
`signify`(ed25519/blake2b) is pure userland and valuable: it signs `abzu-pkg`
metadata and distfiles. Add `signify` to the portmap and teach
`verify-packages.sh` about `.sig`. Also verify `sha256.sig` after fetch (§E4).

### C5. Build-system friction (where ports actually stall)

OpenBSD userland builds with `bsd.prog.mk`/`bsd.lib.mk`, expecting `${.CURDIR}`,
`${BSDSRCDIR}`, OBJ dirs, in-base `libcrypto`, implicit `-lc -lpthread`, and
`make`-variable-driven toolchains. Darwin ships none of those `.mk` files.

| strategy | effort | fidelity |
|---|---|---|
| **(P) Portmap** — machine-readable per-tool recipe (sources *or* configure cmd, libs, compat objects, install dir, man sections, profile, tier) | low per tool, auditable | exact flags; **chosen** |
| **(B) Backport `share/mk`** — vendor bsd.mk and neutralise kernel-header deps | very high | maximal reuse, brittle, drags `obj`/`lint` machinery |

With (P) the driver becomes a thin executor instead of a `find`-based guesser.
Autotools tools (`tmux`, `rsync`, `sqlite3`, `unbound`) declare
`mode=config` and receive a generated `config.h` flipping `HAVE_*` keys to match
libSystem reality.

## D. Licensing note

OpenBSD code is ISC/BSD-family: compatible with MIT and with linking against
APSL-covered Darwin headers. GNUstep (GPL/LGPL) stays arm's-length in `gui/`.
`bash` (GPLv3) must not enter the base image — ksh(1) as `/bin/sh` avoids it.
`docs/LICENSES.md` (referenced by the README but missing) is added to record
per-tool licence + provenance for distribution audits.

## E. Concrete defects found while taking stock

1. **Manifest parsing drops tools.** Driver reads field 1 only, so `cp mv rm`
   yields `cp` and silently loses `mv`/`rm`; `ssh scp sftp sshd` yields `ssh`,
   which isn't a directory in `src.tar.gz` (it's `usr.bin/ssh`). → one row per
   tool in `import/portmap.tsv`.
2. **Skip matching is dead code.** `grep -qx "${want}" skip.txt` compares
   against lines carrying trailing comments, so `-x` never matches and nothing is
   ever skipped. → strip comments before comparison.
3. **`do_fetch` breaks after the first manifest row**, making the src loop
   effectively single-shot; rewritten explicitly.
4. **`sha256.sig` is downloaded and never verified.** → verification step added.
5. **Shim patches applied from `${SRCDIR%/*}`** — one level above the tool dir,
   wrong for nested dirs (`usr.bin/ssh`). → apply inside `${SRCDIR}`.
6. **`make PROG=${want}` presumes `bsd.prog.mk`** (§C5). → portmap-driven build
   commands.
7. **`do_stage` classifies binaries by basename heuristics**, misplacing tools and
   sweeping stray objects into `/usr/bin`. → honour declared install dirs.
8. **Dangling `/etc/sandbox.d/abzu-services.sb`** referenced from two generators.
   → profiles shipped from `userland/etc/sandbox.d/`.
9. **`master.passwd` is 644 in-tree**; the derivation chmods only the copy. →
   overlay made 600 + a check.
10. **`tools.manifest` lists `unwind` while `skip.txt` forbids it** —
    contradictory. → removed; `unbound` imported instead.

Fixes land in the accompanying commit; per-change rationale in
[`../userland/PORTING-NOTES.md`](../userland/PORTING-NOTES.md).
