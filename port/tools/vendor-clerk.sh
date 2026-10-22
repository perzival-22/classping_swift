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
# Keep only what ClerkKit needs. It has no dependencies of its own, so the copy gets a manifest with
# just that target: ClerkKitUI (can't build under xtool), the test targets (their folders aren't
# copied) and the packages only those use (Nuke, PhoneNumberKit, the test helpers) are left out.
mkdir -p "$DEST/Sources"
cp -r "$TMP/clerk-ios/Sources/ClerkKit" "$DEST/Sources/ClerkKit"
cp "$TMP/clerk-ios/LICENSE" "$DEST/LICENSE"
cat > "$DEST/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
// ClerkKit from clerk-ios, vendored by port/tools/vendor-clerk.sh (D-96): the
// upstream manifest cut down to the one target the app uses.
import PackageDescription

let package = Package(
  name: "Clerk",
  defaultLocalization: "en",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [.library(name: "ClerkKit", targets: ["ClerkKit"])],
  targets: [
    .target(
      name: "ClerkKit",
      path: "Sources/ClerkKit",
      resources: [.process("Resources")],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
SWIFT
printf 'clerk-ios %s (https://github.com/clerk/clerk-ios), ClerkKit only. String Catalogs converted to .strings and the manifest cut down by port/tools/vendor-clerk.sh (D-96), because xtool cannot run xcstringstool or actool on Linux. Redo with that script to upgrade; never edit by hand.\n' "$TAG" > "$DEST/VENDORED.txt"
echo "VENDORED clerk-ios $TAG at $DEST ($(du -sh "$DEST" | cut -f1), $(find "$DEST" -type f | wc -l) files)"
