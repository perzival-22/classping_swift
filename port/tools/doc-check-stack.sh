#!/usr/bin/env bash
# doc-check-stack.sh: doc-check.sh for a phase written before Kelvin has typed
# the ones before it. Lays the code blocks of every doc given, in order, over
# a copy of Kelvin's current Sources, diffs that against the reference, and
# builds it with build-check.sh. Never touches ~/ClassPing.
# Usage: bash -l doc-check-stack.sh phase-08a-notes-write-and-find.md phase-08b-the-reader.md
IOS=/mnt/c/Users/kelvi/Desktop/classping/docs/ios
REF="$IOS/reference/Sources/ClassPing"
rm -rf /tmp/cpstack && mkdir -p /tmp/cpstack && cp -r ~/ClassPing/Sources/ClassPing/. /tmp/cpstack/
for doc in "$@"; do
  echo "--- $doc"
  python3 "$IOS/tools/doc-extract.py" "$IOS/$doc" /tmp/cpstack
done
echo "--- diff against the reference (nothing above IDENTICAL = identical):"
diff -r /tmp/cpstack "$REF" && echo IDENTICAL
bash -l "$IOS/tools/build-check.sh" /tmp/cpstack
rm -rf /tmp/cpstack
