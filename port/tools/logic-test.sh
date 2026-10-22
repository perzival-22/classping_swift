#!/usr/bin/env bash
# logic-test.sh: runs the Swift ports of the web app's lib/*.test.ts cases on Linux.
# Copies the Foundation-only Logic/ files and their tests into a throwaway package.
set -euo pipefail
IOS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../reference" && pwd)"
SRC="${1:-$IOS/Sources/ClassPing/Logic}"
TESTS="${2:-$IOS/Tests/Logic}"
PROBE="$(mktemp -d /tmp/classping-reference-logic.XXXXXX)"
trap 'rm -rf -- "$PROBE"' EXIT
cd "$PROBE"
swift package init --type library --name CPLogic > /dev/null 2>&1
rm -f Sources/CPLogic/*.swift Tests/CPLogicTests/*.swift
cp -r "$SRC"/. Sources/CPLogic/
cp -r "$TESTS"/. Tests/CPLogicTests/
swift test
