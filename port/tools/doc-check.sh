#!/usr/bin/env bash
# doc-check.sh: proves a phase doc's code is what was verified.
# Extracts every "### 4.N `~/ClassPing/Sources/ClassPing/<path>`" code block from the doc,
# lays them over a copy of Kelvin's current Sources, diffs that against the reference,
# and builds it with build-check.sh. Never touches ~/ClassPing.
# Usage: bash -l doc-check.sh phase-07a-reminders-ring.md
set -euo pipefail
IOS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$IOS/$1"
REF="$IOS/reference/Sources/ClassPing"
PROBE="$(mktemp -d /tmp/classping-doc.XXXXXX)"
trap 'rm -rf -- "$PROBE"' EXIT
cp -r ~/ClassPing/Sources/ClassPing/. "$PROBE/"
python3 "$IOS/tools/doc-extract.py" "$DOC" "$PROBE"
echo "--- diff against the reference (nothing above IDENTICAL = identical):"
diff -r "$PROBE" "$REF"
echo IDENTICAL
bash -l "$IOS/tools/build-check.sh" "$PROBE"
