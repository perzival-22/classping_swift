#!/usr/bin/env bash
# build-check.sh: compiles the reference iOS code in a throwaway xtool project.
# It never touches ~/ClassPing. Pass a different folder as $1 to test other code.
set -euo pipefail
REF="${1:-/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Sources/ClassPing}"
PROBE="$(mktemp -d /tmp/classping-build.XXXXXX)"
trap 'rm -rf -- "$PROBE"' EXIT
cd "$PROBE"
xtool new CPProbe --skip-setup > /dev/null 2>&1 || { echo "PROBE_SETUP_FAILED"; exit 1; }
cd CPProbe
sed -i 's/.iOS(.v17)/.iOS(.v18)/' Package.swift
rm -f Sources/CPProbe/*.swift
cp -r "$REF"/. Sources/CPProbe/
status=0
xtool dev build > "$PROBE/build.log" 2>&1 || status=$?
sed 's/\x1b\[[0-9;]*m//g' "$PROBE/build.log" | grep -E "error:|warning:" | sort -u || true
if [ "$status" = 0 ] && grep -q -E "Build complete|Wrote to" "$PROBE/build.log"; then
  echo "BUILD_OK"
else
  tail -30 "$PROBE/build.log"
  echo "BUILD_FAILED"
  exit 1
fi
