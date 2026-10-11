#!/bin/sh
# update-src-hashes.sh — resolve every pin in build/config/sources.json + the
# flake srcInfo block to immutable commit SHAs and print/record the Nix
# `sha256` hashes for them.
#
# Usage: ./update-src-hashes.sh            # prints paste-ready updates
#        ./update-src-hashes.sh --write    # rewrites sources.json AND the
#                                          # srcInfo block in ../flake.nix
#
# Requires: nix (for `nix-prefetch-url --unpack`), curl, python3.
#
# AUDIT FIXES (2026-10-11):
#   * HASH TYPE: companion entries were written as RAW-ARCHIVE digests while
#     xnu-sources.nix consumes them through `fetchzip`, which requires the
#     RECURSIVE (unpacked-tree) SRI hash — guaranteed "hash mismatch in
#     fixed-output derivation" on every evaluation. This script now always
#     uses `nix-prefetch-url --unpack` and converts to SRI before writing,
#     so what lands in sources.json is fetchzip-compatible by construction.
#   * XNU PINS NEVER WRITTEN: the old version printed the resolved xnu rev +
#     hash but only persisted the companions; the flake kept a placeholder
#     sha256 AAAA... forever. --write now also patches srcInfo.xnuRev /
#     srcInfo.xnuSha256 in ../flake.nix (regex-anchored, fails closed if the
#     anchors moved).
#   * TAG DRIFT: default tag follows the flake's Catalina pin (xnu-4903.278.28);
#     override with XNU_TAG=<tag> to retarget another release train. Companion
#     repos must be pinned to tags from the SAME train; unresolved/"TBD"
#     entries are reported and skipped rather than silently kept stale.
set -eu
REPO="https://github.com/apple-oss-distributions"
XNU_TAG="${XNU_TAG:-xnu-4903.278.28}"   # macOS 10.15.7 Catalina OSS drop
HERE="$(cd "$(dirname "$0")" && pwd)"
CFG="${HERE}/../config/sources.json"
FLAKE="${HERE}/../flake.nix"

resolve_rev() { # <repo-name> <tag-or-ref> -> 40-hex commit sha (dereferences annotated tags)
    name="$1"; ref="$2"
    sha=$(curl -sf "${REPO}/${name}/git/ref/tags/${ref}" \
      | python3 -c 'import json,sys; d=json.load(sys.stdin)["object"]; print(d["sha"] if d["type"]=="commit" else "")' 2>/dev/null || true)
    if [ -z "${sha}" ]; then
        # annotated tag -> object points at the tag; dereference it
        obj=$(curl -sf "${REPO}/${name}/git/ref/tags/${ref}" \
          | python3 -c 'import json,sys; d=json.load(sys.stdin)["object"]; print(d["url"] if d["type"]=="tag" else "")' 2>/dev/null || true)
        [ -n "${obj}" ] && sha=$(curl -sf "${obj}" \
          | python3 -c 'import json,sys; print(json.load(sys.stdin)["object"]["sha"])' 2>/dev/null || true)
    fi
    if [ -z "${sha}" ]; then
        sha=$(curl -sf "${REPO}/${name}/commits?sha=${ref}&per_page=1" \
          | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["sha"])' 2>/dev/null || true)
    fi
    if [ -n "${sha:-}" ] && [ "${#sha}" = 40 ]; then echo "$sha"; return 0; fi
    echo "ERROR: could not resolve ${name}@${ref} (does the tag exist on the ${XNU_TAG%-*} release train?)" >&2
    return 1
}

hash_of() { # <name> <rev> -> SRI recursive (unpacked-tree) hash for fetchzip
    url="${REPO}/$1/archive/$2.tar.gz"
    raw=$(nix-prefetch-url --unpack "$url") \
      || { echo "ERROR: nix-prefetch-url failed for $url" >&2; return 1; }
    nix hash convert --hash-algo sha256 --to sri "$raw" 2>/dev/null || echo "$raw"
}

echo "==> XNU ${XNU_TAG}"
XNU_REV=$(resolve_rev xnu "${XNU_TAG}")
XNU_SHA=$(hash_of xnu "${XNU_REV}")
echo "srcInfo.xnuRev    = \"${XNU_REV}\";"
echo "srcInfo.xnuSha256 = \"${XNU_SHA}\";"

python3 - "$CFG" "${FLAKE}" "${1:-}" "${XNU_REV}" "${XNU_SHA}" <<'PY'
import json, re, subprocess, sys

cfg_path, flake_path, mode, xnu_rev, xnu_sha = sys.argv[1:6]

# --- companions -------------------------------------------------------------
d = json.load(open(cfg_path))
changed = False
for name, spec in list(d.items()):
    if name == "_comment":
        continue
    if not spec.get("rev") or spec["rev"] == "TBD":
        print(f"# {name}: UNRESOLVED — set spec['rev'] to the tag matching "
              f"{xnu_rev} on https://github.com/apple-oss-distributions/{name}/tags, "
              f"then rerun.", file=sys.stderr)
        continue
    url = f"https://github.com/apple-oss-distributions/{name}/archive/{spec['rev']}.tar.gz"
    h = subprocess.run(["nix-prefetch-url", "--unpack", url],
                       capture_output=True, text=True).stdout.strip()
    if not h:
        print(f"# {name}: nix-prefetch-url FAILED for {url}", file=sys.stderr)
        continue
    sri = subprocess.run(["nix", "hash", "convert", "--hash-algo", "sha256",
                          "--to", "sri", h], capture_output=True, text=True).stdout.strip() or h
    if sri != spec.get("sha256"):
        print(f"{name}: {spec.get('sha256')} -> {sri}")
        spec["sha256"] = sri
        changed = True
    else:
        print(f"{name}: unchanged ({sri})")

if mode == "--write":
    if changed:
        json.dump(d, open(cfg_path, "w"), indent=2)
        print("wrote", cfg_path)
    else:
        print("sources.json already current; not rewritten")

    # --- flake srcInfo block -------------------------------------------------
    # Rewrite xnuTag / xnuRev / xnuSha256 in place, anchored on the attribute
    # names (fails closed below if any anchor moved).
    import os
    src = open(flake_path).read()
    new = src
    tag = os.environ.get("XNU_TAG", "xnu-4903.278.28")
    pat_rev  = re.compile(r'(xnuRev\s*=\s*)"[^"]*"')
    pat_sha  = re.compile(r'(xnuSha256\s*=\s*)"[^"]*"')
    pat_tag  = re.compile(r'(xnuTag\s*=\s*)"[^"]*"')
    new, r1 = pat_rev.subn(lambda m: m.group(1) + '"%s"' % xnu_rev, new)
    new, r2 = pat_sha.subn(lambda m: m.group(1) + '"%s"' % xnu_sha, new)
    new, r3 = pat_tag.subn(lambda m: m.group(1) + '"%s"' % tag, new)
    if not (r1 and r2 and r3):
        sys.exit(f"ERROR: flake srcInfo anchors not found (rev={r1} sha={r2} tag={r3}) — "
                 f"edit build/flake.nix manually")
    if new != src:
        open(flake_path, "w").write(new)
        print("wrote", flake_path, "(srcInfo xnuTag/xnuRev/xnuSha256 updated)")
    else:
        print("flake.nix srcInfo already current")
elif mode not in ("--write",):
    print("(pass --write to persist resolved hashes into sources.json + flake.nix)")
PY
