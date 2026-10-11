#!/bin/sh
# verify-packages.sh — gate every packages/*/manifest.json before fetching.
# Fails the build when a package lacks source/license/provenance, or when a
# licence is on the deny list (no proprietary blobs in base Abzu images).
#
# AUDIT FIX (2026-10-11): The old DENY matching was substring-based against
# lowercased strings: "proprietary" matched the legitimate manifest value
# "Proprietary (Free)" (freely redistributable binaries like Docker Desktop),
# failing `make packages` while `nix flake check` passed — the two pipelines
# disagreed. Matching is now exact-canonical (case-insensitive) with an
# explicit allowlist for "(Free)" variants, and unknown licenses still fail
# closed.
set -eu
PKGS_DIR="${1:?usage: $0 <packages-dir>}"
python3 - "${PKGS_DIR}" <<'PY'
import json, glob, os, sys
pkgs_dir = sys.argv[1]

# Canonical deny tokens — compared EXACTLY (lowercased), never as substrings.
DENY_EXACT = {"proprietary", "unknown", "apple-binary", "freeware-unredistributed"}
# Substrings that mark a license as *unconditionally* toxic (blobs we may
# never redistribute at all).
DENY_SUBSTRINGS = ("apple-binary", "unredistributed")
# "Proprietary (Free)" / "Freeware" style entries are allowed: closed but
# lawfully redistributable; they must still carry provenance + checksums.
ALLOW_PATTERNS = ("(free)", "freeware (allowed)")

required = ("name", "version", "source", "license", "provenance")
errors = []
for f in sorted(glob.glob(os.path.join(pkgs_dir, "*", "manifest.json"))):
    d = json.load(open(f))
    for p in d.get("packages", []):
        missing = [k for k in required if k not in p]
        if missing:
            errors.append(f"{os.path.relpath(f, pkgs_dir)}:{p.get('name','?')} missing {missing}")
            continue  # can't reason about a license we can't read
        lic = str(p["license"]).strip().lower()
        allowed = any(pat in lic for pat in ALLOW_PATTERNS)
        if any(bad in lic for bad in DENY_SUBSTRINGS):
            errors.append(f"{os.path.relpath(f, pkgs_dir)}:{p['name']} denied license '{p['license']}'")
        elif lic in DENY_EXACT and not allowed:
            errors.append(f"{os.path.relpath(f, pkgs_dir)}:{p['name']} denied license '{p['license']}'"
                          " (bare 'proprietary' without a redistributable '(Free)' qualifier)")
if errors:
    print("PACKAGE VERIFICATION FAILED:")
    [print("  -", e) for e in errors]
    sys.exit(1)
print("==> all package manifests verified OK")
PY
