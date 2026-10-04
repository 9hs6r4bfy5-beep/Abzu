#!/bin/sh
# update-src-hashes.sh — resolve every pin in build/config + flake srcInfo to
# immutable commit SHAs and print the Nix `sha256` hashes for them.
#
# Usage: ./update-src-hashes.sh            # prints paste-ready updates
#        ./update-src-hashes.sh --write    # rewrites config/sources.json in place
#
# Requires: nix (for `nix-prefetch-url --unpack`), curl, python3.
set -eu
REPO="https://github.com/apple-oss-distributions"
XNU_TAG="${XNU_TAG:-xnu-7195.141.2}"   # macOS 11.3 Big Sur OSS drop
CFG="$(cd "$(dirname "$0")/.." && pwd)/config/sources.json"

resolve_rev() { # <repo-name-or-xnu> <tag-or-ref>
    name="$1"; ref="$2"
    sha=$(curl -sf "$REPO/$name/git/ref/tag/$ref" | python3 -c 'import json,sys; d=json.load(sys.stdin); o=d["object"]; print(o["url"].rsplit("/",1)[-1])' 2>/dev/null) \
      || sha=$(curl -sf "$REPO/$name/commits?sha=$ref&per_page=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["sha"])')
    if [ -n "${sha:-}" ] && [ "${#sha}" = 40 ]; then echo "$sha"; return 0; fi
    # annotated tags: dereference via git/tags endpoint
    curl -sf "$REPO/$name/git/refs/tags/$ref" \
      | python3 -c 'import json,sys; t=json.load(sys.stdin)["object"]; print(t["sha"] if t["type"]=="commit" else "")' 
}

hash_of() { # <name> <rev>
    url="$REPO/$1/archive/$2.tar.gz"
    nix-prefetch-url --unpack "$url" 2>/dev/null | tr -d '\n' | { read h; nix hash convert --hash-algo sha256 --to sri "$h" 2>/dev/null || echo "$h"; }
    echo
}

echo "==> XNU ${XNU_TAG}"
XNU_REV=$(resolve_rev xnu "$XNU_TAG")
XNU_SHA=$(hash_of xnu "$XNU_REV")
echo "srcInfo.xnuRev    = \"${XNU_REV}\";"
echo "srcInfo.xnuSha256 = \"${XNU_SHA}\";"

python3 - "$CFG" "${1:-}" <<'PY'
import json, subprocess, sys, os
cfg, mode = sys.argv[1], sys.argv[2]
d = json.load(open(cfg))
for name, spec in list(d.items()):
    if name == "_comment" or spec.get("rev") == "TBD":
        print(f"# {name}: unresolved — set spec['rev'] to the tag matching xnu-7195 (see https://github.com/apple-oss-distributions/{name}/tags)")
        continue
    url = f"https://github.com/apple-oss-distributions/{name}/archive/{spec['rev']}.tar.gz"
    h = subprocess.run(["nix-prefetch-url","--unpack",url], capture_output=True, text=True).stdout.strip()
    if h:
        spec["sha256"] = h
        print(f"{name}: {h}")
if mode == "--write":
    json.dump(d, open(cfg,"w"), indent=2); print("wrote", cfg)
else:
    print("(pass --write to persist resolved hashes)")
PY
