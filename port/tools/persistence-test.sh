#!/usr/bin/env bash
# persistence-test.sh: runs the save/load and store-action tests on Linux.
# Copies the SwiftUI-free model and store files into a throwaway package.
# Since Phase 4a the store actions call Logic/ (nextRepeatDate, isValidDate), so
# the Foundation-only Logic/ files are copied too. Since Phase 6b Undo can bring
# back a class (restoreCourse), so Store+Courses.swift is copied as well.
# Since 7a, Models+Reminders.swift (the protocol sign-ups the reminder plan and
# study totals need, which build on Assignment+Deadline and Assignment+TaskView)
# and, since 7b, Store+Planning.swift, and since 8a, Store+Notes.swift, since 9a
# Store+Grades.swift, since 11a Store+Profile.swift and since 11b+c Models+Backup.swift,
# Store+Backup.swift and Store+Trash.swift, since 13a Store+Import.swift, and since 14b Models+Rows.swift (the row mapping). A file a tree doesn't have yet is skipped,
# so the script still runs on older trees.
# The copied persistence source uses a disposable Documents directory.
# The suites share that private file, so run them one at a time.
# Optional: $1 = a Sources/ClassPing folder, $2 = a tests folder (defaults: the reference).
set -euo pipefail
IOS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../reference" && pwd)"
SRC="${1:-$IOS/Sources/ClassPing}"
TESTS="${2:-$IOS/Tests/Persistence}"
PROBE="$(mktemp -d /tmp/classping-reference-store.XXXXXX)"
trap 'rm -rf -- "$PROBE"' EXIT
cd "$PROBE"
swift package init --type library --name CPLogic > /dev/null 2>&1
rm -f Sources/CPLogic/*.swift Tests/CPLogicTests/*.swift
for f in Models Records Profile Store Store+Persistence Store+Assignments Store+Courses Assignment+Deadline Assignment+TaskView Models+Reminders Store+Planning Store+Notes Store+Grades Store+Profile Models+Backup Store+Backup Store+Trash Store+Import Models+Rows Store+Sync; do
  if [ -f "$SRC/$f.swift" ]; then cp "$SRC/$f.swift" Sources/CPLogic/; fi
done
cp "$SRC/Logic/"*.swift Sources/CPLogic/
cp "$TESTS/"*.swift Tests/CPLogicTests/
mkdir Documents
python3 - "$PROBE" <<'PY'
from pathlib import Path
import sys
probe = Path(sys.argv[1])
source = probe / "Sources/CPLogic/Store+Persistence.swift"
text = source.read_text()
original = ('FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first\n'
            '            ?? FileManager.default.temporaryDirectory')
if text.count(original) != 1:
    raise SystemExit("Documents path changed; update test isolation before running tests.")
source.write_text(text.replace(original, f'URL(fileURLWithPath: "{probe}/Documents")'))
PY
swift test --no-parallel
