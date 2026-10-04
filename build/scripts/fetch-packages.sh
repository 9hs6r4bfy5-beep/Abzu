#!/bin/sh
# fetch-packages.sh — resolve packages/* manifests into the staging dir.
# For each shelf entry it records what WILL be vendored (URLs are provenance-
# checked upstream by verify-packages.sh) and stages project-original tools
# (like abzu-firewall) directly. Binary emulation packages are installed by
# their nix derivations in the reproducible path; here we drop a resolved
# manifest the ISO installer reads at first boot ("install on demand" shelf).
set -eu
PKGS="${1:?usage: $0 <packages-dir> <staging-dir>}"
STAGE="${2:?usage: $0 <packages-dir> <staging-dir>}"
mkdir -p "${STAGE}/usr/local/archives/manifests" "${STAGE}/Applications"

python3 - "$PKGS" "$STAGE" <<'PY'
import json, glob, os, shutil, sys
pkgs, stage = sys.argv[1], sys.argv[2]
for f in sorted(glob.glob(os.path.join(pkgs, "*", "manifest.json"))):
    d = json.load(open(f))
    dst = os.path.join(stage, "usr/local/archives/manifests", os.path.basename(os.path.dirname(f)) + ".json")
    shutil.copyfile(f, dst)
    print("staged manifest:", dst)
