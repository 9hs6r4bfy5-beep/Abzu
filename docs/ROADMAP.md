# Abzu roadmap — OpenBSD userland on Darwin/XNU

Sequenced plan derived from [`OPENBSD-DIFFS.md`](OPENBSD-DIFFS.md). Ordering rule:
**a security primitive is only "shipped" when it fails closed.** Quality-of-life
work follows, because most QoL tools want `pledge`/`unveil` in place before they
can be hardened.

Tiers (from `userland/import/portmap.tsv`, column 9):

| tier | meaning | gate |
|---|---|---|
| 1 | security-critical or needed to build tier ≥2 (`doas`, `ksh`, `signify`, `libc` bits) | must land with a sandbox profile + shim patch |
| 2 | core QoL (`ls cp mv rm`, `vi`, `mandoc`, `man`, `nc`) | must pass the smoke suite |
| 3 | services (`sshd`, `ntpd`, `httpd`, `unbound`, `relayd`) | must have launchd plist + rc.d row + privdrop user |
| 4 | optional shelf (`tmux`, `rsync`, `sqlite3`) | no image guarantee |

---

## M0 — Make the pipeline honest (done in this change)

- [x] `docs/OPENBSD-DIFFS.md`: difference analysis (§B/§C) and defect list (§E).
- [x] Replace ambiguous `tools.manifest` with one-tool-per-line
      `userland/import/portmap.tsv` (source dir, build mode, sources/configure,
      extra libs, compat objects, install dir, man sections, tier, notes).
- [x] Fix driver defects E1–E7: comment-stripped skip matching, per-row parsing,
      patch applied inside the tool dir, portmap-driven build commands, declared
      install dirs at staging, distfile checksum verification.
- [x] `abzu-compat.c`: `pledge()/unveil()` stop lying — translate promises to a
      seatbelt profile via `sandbox_init(3)`, honour `ABZU_PLEDGE=fail|warn|off`;
      add `timingsafe_bcmp/timingsafe_memcmp`, version-gated `explicit_bzero`.
- [x] Ship the previously dangling `/etc/sandbox.d/*.sb` profiles and the
      `pledge-map.tsv` they are generated from.
- [x] Add `login.conf`, `motd`, `rc.d.tsv`; make `assemble-rootfs.sh` **and**
      `rootfs.nix` both consume `rc.d.tsv` (single source of truth for daemons).
- [x] `docs/LICENSES.md` (referenced by README but missing until now).

## M1 — Security primitives usable end-to-end (next)

- [ ] **Pledge translation coverage test**: run every tier-1/2 tool under
      `ABZU_PLEDGE=fail` in CI; any unmapped promise string is a build failure.
      Deliverable: `userland/security/test-pledge-map.sh`.
- [ ] **doas on Darwin** (`mach_compat/doas.patch`): compile out PAM/libutil,
      `getpeereid(3)` persist check, `login.conf` classes, bcrypt hashing,
      explicit 4755 install on APFS. Acceptance: `doas -u root id` from a
      `:wheel` member; non-wheel denied; `deny` catch-all last line effective.
- [ ] **pwd.db bootstrap**: `abzu-init` runs `pwd_mkdb -p /etc/master.passwd`,
      creates `tty` group + fixes `/dev/ttyp*` ownership (diffs §B3).
- [ ] **W^X kernel hook rewrite** (patch 0002 → real `SYSCTL_PROC`, boot-arg
      parsed in `bsd/kern/kern_sysctl.c`, Developer-mode override), verified with
      `git apply --check` against `xnu-7195.141.2` in CI (see
      `kernel/patches/README.md`).
- [ ] **signify port** + `.sig` verification in `build/scripts/verify-packages.sh`
      and `fetch-distfiles.sh` (diffs §C4).
- [ ] **fail-closed firewall**: `abzu-firewall` writes
      `/etc/abzu/firewall.pending` and blocks `requires-firewall` services when no
      backend exists (diffs §B4).

## M2 — Core quality of life

- [ ] ksh(1) as `/bin/sh` (`mach_compat/ksh.patch` for termios/`TIOCGWINSZ`);
      `ls/cp/mv/rm` BSD install semantics; `vi`; `nc`.
- [ ] `mandoc` + `man` corpus from the imported src tree, `makewhatis` →
      `/var/db/man`; ship `apropos`/`whatis` aliases. (Highest-value QoL item.)
- [ ] `etc/motd` refresh hook + `abzu-ctl` front-end reading `rc.d.tsv`
      (`enable/disable/status/start/stop` mapped onto `launchctl`).
- [ ] Case-sensitive root volume decision (risk R-Q3) — affects `mandoc`,
      `sqlite3`, `pkg` metadata.

## M3 — Services (tier 3)

- [ ] `sshd` from OpenBSD portable with our `sshd_config` baseline
      (`KbdInteractiveAuthentication no`, root login only via doas).
- [ ] `ntp`/`ntpd` with privilege separation confirmed under a generated profile.
- [ ] `unbound` replacing `unwind` (skip.txt already excludes unwind); resolver
      wired into `abzu-ctl`.
- [ ] `httpd` for local docs/archives; `relayd` **only** after the pf shim lands
      (otherwise stays in skip.txt — today it is listed in both, which is the bug
      we fixed).
- [ ] Every daemon: plist from `rc.d.tsv` + profile from `sandbox.d/` +
      `_www`-style privdrop user present in `master.passwd` skeleton.

## M4 — Kernel-side fidelity (post-MVP)

- [ ] Patch 0003: real `pledge`/`unveil` syscalls in `bsd/kern` (promise mask on
      `struct proc`, enforcement at open/exec/socket/ioctl, `ps -O pledge`).
- [ ] `proc_setconcurrency`, `recallocarray`, guard-page malloc parity.
- [ ] Re-evaluate `pf` — either an XNU `dlil`-level port or keep `abzu-firewall`
      as the supported answer and document the limitation.

---

## Risks

| id | risk | mitigation |
|---|---|---|
| R-S1 | No-op `pledge` giving false assurance | M0 made it fail-closed; CI test in M1 |
| R-S2 | XNU patch drift across release trains | minimal single-hook patches, `git apply --check` in CI, three-way re-roll documented |
| R-S3 | doas auth path differs on APFS/OpenDirectory | explicit local-file auth, tested on both HFS+ and APFS builders |
| R-Q1 | Case-insensitive root breaks several tools | decide CS volume in M2 (R-Q3) |
| R-Q2 | `share/mk` absence stalls ports | portmap strategy (P); autotools `mode=config` escape hatch |
| R-L1 | GPL creep via bash/pkg tools | ksh as `/bin/sh`; `docs/LICENSES.md` audit gate in `make check` |
| R-B1 | Linux builders produce skeleton images only | `STATUS`/`.abzu-image-kind` markers kept; Darwin builder job added to CI matrix |

## Definition of done for "OpenBSD userland ported"

1. `nix build .#openbsd-userland` yields Mach-O binaries for all tier-1..3 tools
   on a Darwin builder (and a marked skeleton elsewhere).
2. No tool links a silently-succeeding security stub.
3. `sudo` absent, `doas` policy enforced, root locked, first-boot wizard sets a
   bcrypt hash.
4. Every shipped daemon has a launchd plist *and* a sandbox profile that exists.
5. `man` renders the imported OpenBSD manual corpus for each ported tool.
