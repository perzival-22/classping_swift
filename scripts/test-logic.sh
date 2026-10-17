#!/usr/bin/env bash
# Run the Foundation-only planner logic without requiring an Apple SDK.
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
probe_dir="$(mktemp -d /tmp/classping-logic.XXXXXX)"
trap 'rm -rf -- "$probe_dir"' EXIT
cd "$probe_dir"
swift package init --type library --name CPLogic >/dev/null
rm Sources/CPLogic/*.swift Tests/CPLogicTests/*.swift
cp "$project_root"/Sources/ClassPing/Logic/*.swift Sources/CPLogic/
cp "$project_root"/Tests/Logic/*.swift Tests/CPLogicTests/
swift test
