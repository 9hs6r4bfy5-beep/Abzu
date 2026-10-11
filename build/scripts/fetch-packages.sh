#!/bin/sh
# fetch-packages.sh — resolve packages/* manifests into the staging dir.
# For each shelf entry it records what WILL be vendored (URLs are provenance-
# checked upstream by verify-packages.sh) and stages project-original tools
# (like abzu-firewall) directly. Binary emulation packages are installed by
# their nix derivations in the reproducible path; here we drop a resolved
# manifest the ISO installer reads at first boot ("install on demand" shelf).
#
# AUDIT FIX (2026-10-11): the previous version ended with an UNTERMINATED
# here-document — the `<<'PY'` block had no closing `PY` delimiter, so /bin/sh
# hit EOF while scanning for it and aborted with:
#     syntax error: heredoc delimited by end-of-file undefined
# which failed `make packages` (and therefore `make rootfs`/`make iso`) on a
# fresh clone. The closing delimiter is now explicit. Also hardened:
#   * fail closed when a manifest is not valid JSON or lacks "packages";
#   * emit a machine-readable resolved index (resolved.json) the first-boot
#     installer consumes, instead of only pretty-printing to stdout;
#   * stage project-original scripts (abzu-firewall.sh) when present.
set -eu
PKGS="${1:?usage: $0 <packages-dir> <staging-dir>}"
STAGE="${2:?usage: $0 <packages-dir> <staging-dir>}"
[ -d "${PKGS}" ] || { echo "ERROR: packages dir ${PKGS} does not exist" >&2; exit 1; }
mkdir -p "${STAGE}/usr/local/archives/manifests" "${STAGE}/Applications"

python3 - "$PKGS" "$STAGE" <<'PY'
import json, glob, os, shutil, sys

pkgs, stage = sys.argv[1], sys.argv[2]
manifests_dir = os.path.join(stage, "usr/local/archives/manifests")
resolved = []
errors = []

for f in sorted(glob.glob(os.path.join(pkgs, "*", "manifest.json"))):
    category = os.path.basename(os.path.dirname(f))
    try:
        d = json.load(open(f))
    except (json.JSONDecodeError, OSError) as e:
        errors.append(f"{f}: unreadable manifest ({e})")
        continue
    if "packages" not in d or not isinstance(d["packages"], list):
        errors.append(f"{f}: missing 'packages' list")
        continue
    dst = os.path.join(manifests_dir, category + ".json")
    shutil.copyfile(f, dst)
    print("staged manifest:", dst)
    for p in d["packages"]:
        resolved.append({
            "category":   category,
            "name":       p.get("name"),
            "version":    p.get("version"),
            "source":     p.get("source"),
            "license":    p.get("license"),
            "provenance": p.get("provenance"),
        })

# Stage project-original tools that ship as source scripts (not shelf URLs).
firewall = os.path.join(pkgs, "homelab", "abzu-firewall.sh")
if os.path.isfile(firewall):
    dst = os.path.join(stage, "usr/local/sbin", "abzu-firewall")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(firewall, dst)
    os.chmod(dst, 0o755)
    print("staged tool:", dst)

index = os.path.join(manifests_dir, "resolved.json")
with open(index, "w") as fh:
    json.dump({"entries": resolved, "count": len(resolved)}, fh, indent=2)
print("resolved index:", index, f"({len(resolved)} entries)")

if errors:
    print("FETCH-PACKAGES FAILED:", file=sys.stderr)
    [print("  -", e, file=sys.stderr) for e in errors]
    sys.exit(1)
PY
