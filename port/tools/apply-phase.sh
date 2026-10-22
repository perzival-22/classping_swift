#!/usr/bin/env bash
# apply-phase.sh: puts one verified phase guide into Kelvin's ~/ClassPing, on its own branch (D-93).
#
# Usage (from Windows):  wsl -d Ubuntu -- bash -l /mnt/c/Users/kelvi/Desktop/classping/docs/ios/tools/apply-phase.sh <guide.md> [base]
#   base defaults to main. Give the previous phase's branch to stack a phase on one Kelvin hasn't merged yet.
#
# What it does, in order:
#   1. Stops unless ~/ClassPing is clean, <base> exists and the branch ios/<guide name> doesn't exist yet.
#   2. Rehearses everything on a throwaway copy in /tmp first: lays the guide's "### 4.N" Swift blocks over
#      Sources/ClassPing (doc-extract.py), copies the test files the guide's "cp $R/..." lines name, adds any
#      store files named in the guide's "<!-- store-files: A B -->" marker to scripts/test-store.sh, then checks
#      Sources against the reference (IDENTICAL, blank lines ignored), runs Kelvin's own scripts/test-logic.sh and
#      scripts/test-store.sh, and builds with build-check.sh.
#   3. Only if all of that passes: makes the branch from <base> in ~/ClassPing, applies the same changes, commits on
#      the branch, and switches back to the branch he was on.
# It never touches main's history, never pushes, never runs xtool dev. Kelvin reviews and merges:
#   git switch main && git merge --ff-only ios/<guide name>
set -euo pipefail
IOS=/mnt/c/Users/kelvi/Desktop/classping/docs/ios
GUIDE="${1:?usage: apply-phase.sh <guide.md> [base]}"
BASE="${2:-main}"
DOC="$IOS/$GUIDE"
[ -f "$DOC" ] || { echo "NO_GUIDE $DOC"; exit 2; }
NAME="$(basename "$GUIDE" .md)"
BR="ios/$NAME"
REPO="${CLASSPING_REPO:-$HOME/ClassPing}"   # override only to test this script on a clone
REFT="$IOS/reference/Tests"

# --- 1. guards on Kelvin's repo
cd "$REPO"
[ -z "$(git status --porcelain)" ] || { echo "DIRTY: ~/ClassPing has uncommitted changes, nothing was applied"; git status --short; exit 2; }
git rev-parse --verify --quiet "refs/heads/$BASE" > /dev/null || { echo "NO_BASE: no branch $BASE"; exit 2; }
WAS="$(git rev-parse --abbrev-ref HEAD)"
! git rev-parse --verify --quiet "refs/heads/$BR" > /dev/null || { echo "BRANCH_EXISTS: $BR"; exit 2; }

# apply_to <repo folder> <list file>: the guide's changes, as files (no git); the files written go in <list file>
apply_to() {
  local dir="$1"
  python3 "$IOS/tools/doc-extract.py" "$DOC" "$dir/Sources/ClassPing" > "$2"
  tail -1 "$2"
  python3 - "$DOC" "$REFT" "$dir" <<'PY'
import re, sys, shutil, pathlib
doc, reft, repo = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
md = doc.read_text()
n = 0
for line in md.splitlines():
    line = line.split("#", 1)[0].strip()
    if not line.startswith("cp $R/"):
        continue
    parts = line.split()[1:]
    dest = parts[-1].rstrip("/")
    for src in parts[:-1]:
        s = reft / src.replace("$R/", "", 1)
        d = repo / dest
        d.mkdir(parents=True, exist_ok=True)
        shutil.copy(s, d / s.name)
        n += 1
print(f"{n} test files copied")
m = re.search(r"<!--\s*store-files:\s*([^>]*?)\s*-->", md)
if m:
    script = repo / "scripts/test-store.sh"
    text = script.read_text()
    loop = re.search(r"(for source in )([^;]*)(; do)", text)
    words = loop.group(2).split()
    added = [w for w in m.group(1).split() if w not in words]
    if added:
        text = text[:loop.start(2)] + " ".join(words + added) + text[loop.end(2):]
        script.write_text(text)
    print("store files added to test-store.sh:", " ".join(added) or "(none)")
PY
}

# --- 2. rehearsal on a throwaway copy
PROBE="$(mktemp -d /tmp/classping-apply.XXXXXX)"
trap 'rm -rf -- "$PROBE"' EXIT
mkdir -p "$PROBE/repo"
git -C "$REPO" archive "$BASE" | tar -x -C "$PROBE/repo"   # the base as committed, nothing else
echo "=== rehearsal in $PROBE"
apply_to "$PROBE/repo" "$PROBE/rehearsal.written"
echo "--- the guide's files against the reference (blank lines ignored)"
bad=0
while read -r _ f; do
  diff -B "$PROBE/repo/Sources/ClassPing/$f" "$IOS/reference/Sources/ClassPing/$f" > "$PROBE/ref.diff" || { echo "DIFFERS $f"; head -30 "$PROBE/ref.diff"; bad=1; }
done < <(grep '^wrote ' "$PROBE/rehearsal.written")
[ "$bad" = 0 ] || { echo "NOT_IDENTICAL: nothing was applied to ~/ClassPing"; exit 1; }
echo IDENTICAL
# Whole tree: anything else that differs is in a later guide (the reference runs ahead when guides are stacked).
AHEAD="$(diff -rqB "$PROBE/repo/Sources/ClassPing" "$IOS/reference/Sources/ClassPing" | sed "s|$PROBE/repo/Sources/ClassPing|his|; s|$IOS/reference/Sources/ClassPing|reference|" || true)"
[ -z "$AHEAD" ] && echo "whole tree: equals the reference" || { echo "whole tree: the reference is ahead (later guides):"; echo "$AHEAD" | head -20; }
echo "--- his scripts/test-logic.sh"
bash -l "$PROBE/repo/scripts/test-logic.sh" > "$PROBE/logic.log" 2>&1 || { tail -40 "$PROBE/logic.log"; echo "LOGIC_FAILED: nothing was applied"; exit 1; }
LOGIC="$(grep -oE "Test run with [0-9]+ tests in [0-9]+ suites passed" "$PROBE/logic.log" | tail -1)"
echo "$LOGIC"
echo "--- his scripts/test-store.sh"
bash -l "$PROBE/repo/scripts/test-store.sh" > "$PROBE/store.log" 2>&1 || { tail -40 "$PROBE/store.log"; echo "STORE_FAILED: nothing was applied"; exit 1; }
STORE="$(grep -oE "Test run with [0-9]+ tests in [0-9]+ suites passed" "$PROBE/store.log" | tail -1)"
echo "$STORE"
echo "--- iOS build"
bash -l "$IOS/tools/build-check.sh" "$PROBE/repo/Sources/ClassPing" || { echo "BUILD_FAILED: nothing was applied"; exit 1; }

# --- 3. the real thing, on a branch
cd "$REPO"
git switch -q -c "$BR" "$BASE"
apply_to "$REPO" "$PROBE/real.written" > /dev/null
git add -A Sources Tests scripts
git commit -q -F - <<MSG
$NAME (applied by Claude, D-93)

From docs/ios/$GUIDE. Rehearsed first: Sources IDENTICAL to the reference,
iOS BUILD_OK. Logic: $LOGIC
Store: $STORE

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011EFXGyn5dpmXqSHZ7EVUrn
MSG
git switch -q "$WAS"
echo "=== APPLIED on branch $BR ($(git rev-parse --short "$BR")), from $BASE; ~/ClassPing is back on $WAS"
git --no-pager diff --stat "$BASE..$BR" | tail -20
echo "Review: git diff $BASE..$BR    Merge: git merge --ff-only $BR"
