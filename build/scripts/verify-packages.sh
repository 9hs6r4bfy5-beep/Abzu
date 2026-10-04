#!/bin/sh
# verify-packages.sh — gate every packages/*/manifest.json before fetching.
# Fails the build when a package lacks source/license/provenance, or when a
# licence is on the deny list (no proprietary blobs in base Abzu images).
set -eu
PKGS_DIR="${1:?usage: $0 <packages-dir>}"
python3 - "${PKGS_DIR}" <<'PY'
import json, glob, os, sys
pkgs_dir = sys.argv[1]
DENY = {"proprietary", "unknown", "apple-binary", "freeware-unredistributed"}
required = ("name", "version", "source", "license", "provenance")
errors = []
for f in sorted(glob.glob(os.path.join(pkgs_dir, "*", "manifest.json"))):
    d = json.load(open(f))
    for p in d.get("packages", []):
        missing = [k for k in required if k not in p]
        if missing:
            errors.append(f"{os.path.relpath(f, pkgs_dir)}:{p.get('name','?')} missing {missing}")
        lic = p["license"].lower()
        if any(x in lic for x in DENY):
            errors.append(f"{os.path.relpath(f, pkgs_dir)}:{p['name']} denied license '{p['license']}'")
if errors:
    print("PACKAGE VERIFICATION FAILED:")
    [print("  -", e) for e in errors]
    sys.exit(1)
print("==> all package manifests verified OK")
PY
