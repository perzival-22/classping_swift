#!/usr/bin/env bash
# Test the current Foundation-only store in a disposable package. The copied
# persistence source gets a private Documents path; real planner files stay intact.
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
probe_dir="$(mktemp -d /tmp/classping-store.XXXXXX)"
trap 'rm -rf -- "$probe_dir"' EXIT
cd "$probe_dir"
swift package init --type library --name CPLogic >/dev/null
rm Sources/CPLogic/*.swift Tests/CPLogicTests/*.swift
for source in Models Records Profile Store Store+Persistence Store+Assignments Store+Courses Assignment+Deadline Assignment+TaskView Models+Reminders Store+Planning Store+Notes; do
    cp "$project_root/Sources/ClassPing/$source.swift" Sources/CPLogic/
done
cp "$project_root"/Sources/ClassPing/Logic/*.swift Sources/CPLogic/
cp "$project_root"/Tests/Store/*.swift Tests/CPLogicTests/
mkdir Documents
python3 - "$probe_dir" <<'PY'
from pathlib import Path
import sys
probe = Path(sys.argv[1])
source = probe / 'Sources/CPLogic/Store+Persistence.swift'
text = source.read_text()
original = ('FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first\n'
            '            ?? FileManager.default.temporaryDirectory')
if text.count(original) != 1:
    raise SystemExit('Documents path changed; update test isolation before running tests.')
replacement = f'URL(fileURLWithPath: "{probe}/Documents")'
source.write_text(text.replace(original, replacement))
PY
# Suites share this disposable planner location, so run them one at a time.
swift test --no-parallel
