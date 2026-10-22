#!/usr/bin/env bash
# vendor-clerk.sh: makes the copy of clerk-ios that builds under xtool (spike 1, D-96).
# xtool can't run Apple's xcstringstool on Linux, so ClerkKit's String Catalogs (.xcstrings) are turned into
# <lang>.lproj/Localizable.strings. ClerkKitUI is dropped: its asset catalog needs actool, which xtool can't run
# either, so the sign-in screens are ours, built on ClerkKit.
# Usage: bash -l vendor-clerk.sh <destination folder, e.g. a branch's Vendor/clerk-ios> [tag, default 1.6.1]
set -euo pipefail
DEST="${1:?usage: vendor-clerk.sh <destination> [tag]}"
TAG="${2:-1.6.1}"
[ ! -e "$DEST" ] || { echo "EXISTS: $DEST"; exit 2; }
TMP="$(mktemp -d /tmp/vendor-clerk.XXXXXX)"
trap 'rm -rf -- "$TMP"' EXIT
git -c advice.detachedHead=false clone -q --depth 1 --branch "$TAG" https://github.com/clerk/clerk-ios "$TMP/clerk-ios"
python3 - "$TMP/clerk-ios" <<'PY'
import json, sys, pathlib
root = pathlib.Path(sys.argv[1])
def esc(s): return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
for xc in root.rglob("*.xcstrings"):
    data = json.loads(xc.read_text(encoding="utf-8"))
    src = data.get("sourceLanguage", "en")
    per = {}
    for key, entry in data.get("strings", {}).items():
        locs = entry.get("localizations", {})
        if src not in locs:
            per.setdefault(src, {})[key] = key
        for lang, v in locs.items():
            val = (v.get("stringUnit") or {}).get("value")
            if val is None and "variations" in v:
                val = ((v["variations"].get("plural", {}).get("other") or {}).get("stringUnit") or {}).get("value")
            if val is not None:
                per.setdefault(lang, {})[key] = val
    for lang, kv in per.items():
        d = xc.parent / f"{lang}.lproj"
        d.mkdir(exist_ok=True)
        (d / (xc.stem + ".strings")).write_text("".join(f'"{esc(k)}" = "{esc(v)}";\n' for k, v in kv.items()), encoding="utf-8")
    print(f"converted {xc.relative_to(root)}: {len(data.get('strings', {}))} keys, {len(per)} languages")
    xc.unlink()
PY
rm -rf "$TMP/clerk-ios/.git" "$TMP/clerk-ios/Examples" "$TMP/clerk-ios/Tests"
mkdir -p "$(dirname "$DEST")"
cp -r "$TMP/clerk-ios" "$DEST"
printf 'clerk-ios %s, String Catalogs converted to .strings by docs/ios/tools/vendor-clerk.sh (D-96). Use ClerkKit only.\n' "$TAG" > "$DEST/VENDORED.txt"
echo "VENDORED clerk-ios $TAG at $DEST ($(du -sh "$DEST" | cut -f1))"
