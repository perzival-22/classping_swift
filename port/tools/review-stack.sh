#!/usr/bin/env bash
# review-stack.sh: how Kelvin's typed files differ from what the docs give.
# Lays the docs given, in order, over an empty folder (so it holds only the
# files those docs write, as of the last doc), then diffs each of those files
# against Kelvin's tree. Also builds a copy of Kelvin's tree. Read-only.
# Usage: bash -l review-stack.sh phase-08a-notes-write-and-find.md phase-08b-the-reader.md
IOS=/mnt/c/Users/kelvi/Desktop/classping/docs/ios
rm -rf /tmp/cpwant && mkdir -p /tmp/cpwant
for doc in "$@"; do
  python3 "$IOS/tools/doc-extract.py" "$IOS/$doc" /tmp/cpwant > /dev/null
done
cd /tmp/cpwant || exit 1
for f in $(find . -name '*.swift' | sort); do
  if [ ! -f ~/ClassPing/Sources/ClassPing/$f ]; then echo "MISSING $f"; continue; fi
  if diff -q "$f" ~/ClassPing/Sources/ClassPing/$f > /dev/null; then echo "SAME    $f"; else echo "DIFFERS $f"; diff "$f" ~/ClassPing/Sources/ClassPing/$f | head -40; fi
done
cd /tmp && rm -rf /tmp/cpwant
echo "--- build of Kelvin's tree (a copy):"
rm -rf /tmp/cpkel && cp -r ~/ClassPing/Sources/ClassPing /tmp/cpkel
bash -l "$IOS/tools/build-check.sh" /tmp/cpkel
rm -rf /tmp/cpkel
