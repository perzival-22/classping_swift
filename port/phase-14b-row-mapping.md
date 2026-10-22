---
title: "Phase 14b: The row mapping"
date: 2026-10-22
---
# Phase 14b: The row mapping

A change note (D-93): the code is on the branch `ios/phase-14b-row-mapping`,
pushed by Claude (D-98), built on your `5daaae6` ("Phase 14a"), whose Sources
matched the reference. Nothing to type.

**Verification (2026-10-22, on your laptop before the push):** reference iOS
`BUILD_OK`, no warnings. Logic tests **623/623** in the default zone, New York,
Kolkata, London and Auckland (+10, `ServerValuesTests`). Store tests on the
reference **132/132** (+12, `RowMappingTests`). Your own scripts on a
throwaway copy of your tree with these files: **623/623** and **144/144**, and
its Sources equal the reference. GitHub Actions runs the same scripts and an
unsigned iOS build on every push to this branch (`.github/workflows/checks.yml`).

## 1. Goal

Every model the app keeps (class, assignment, grade, note, planned day, study
session, profile, progress) can now turn into the row the server stores and
back again, under the server's snake_case names. Nothing changes on the phone:
14cd is the phase that sends and receives these rows.

## 2. What it maps from the web

- `lib/supabase/map.ts` to `Models+Rows.swift`: `classToRow`/`rowToClass`,
  `taskToRow`/`rowToTask`, `gradeToRow`/`rowToGrade`, `noteToRow`/`rowToNote`,
  `taskPlanToRow`/`rowToTaskPlan`, `studySessionToRow`/`rowToStudySession`,
  `profileToRow`/`rowToProfile` (with the store's `cleanAvatar`) and
  `gameStateToRow`, as `serverRow(userID:)` and `init?(serverRow:)` on each model.
- `lib/feeds.ts` `normalizeFeeds` to `Models+Rows.swift` (it needs `SavedFeed`);
  `feedLabelFromUrl`, `MAX_FEEDS` and the link check to `Logic/ServerValues.swift`.
- The moments map.ts converts (`toISOString`, `Date.parse`) and its `toDate` to
  `Logic/ServerValues.swift`: `serverInstant`, `instantFromServer`, `serverDay`.
- `lib/supabase/columns.test.ts`'s "the mappers and the column lists agree" and
  "scoping a batch" cases, which 14a had to stand in for, now run on the real
  mappers (`RowMappingTests`).

Where the phone differs from the web (D-99):

- Moments keep whole seconds, as planner.json does (D-73): a row the server
  sends as "…20.5+00:00" goes back as "…20.000Z" (the web would send ".500Z").
- A grade scale, kind or color the phone doesn't know reads as none, a plain
  assignment, or indigo. The web keeps the unknown text and writes it back.
- Class days outside Monday to Sunday are dropped; checklist steps without an
  id or title are dropped (the web keeps both as they are).
- An assignment always carries a kind, so a web task with none goes back as
  "assignment".

## 3. Read these closely

1. `instantFromServer` in `Logic/ServerValues.swift`: it has to read
   everything Postgres and Realtime send ("+00:00", "+00", microseconds, a
   space instead of "T") and match `Date.parse`, including its odd corners
   (February 30 rolls into March). The web's own answers are in
   `Tests/Logic/WebValues14b.swift`.
2. `Profile.init(serverRow:)`: `Number(null)` is 0 on the web, so a row with
   only `quiet_end` set means quiet from midnight. Copied on purpose.
3. `Assignment.serverRow`: a day that isn't real sends no deadline at all, and
   a time with no day is dropped, both ways.
4. `RowMappingTests.aRowAndTheItemItMakesAgree`: whatever the phone builds
   from its own row it writes back unchanged. The merge's fingerprints (14a)
   depend on that.

## 4. Files

New: `Sources/ClassPing/Logic/ServerValues.swift`,
`Sources/ClassPing/Models+Rows.swift`, `Tests/Logic/ServerValuesTests.swift`,
`Tests/Logic/WebValues14b.swift`, `Tests/Store/RowMappingTests.swift`,
`Tests/Store/WebRows14b.swift`.
Changed: `scripts/test-store.sh` (copies `Models+Rows`).
Also on this branch: `port/` (these docs, D-98) and `.github/workflows/checks.yml`.

## 5. Run it

```bash
cd ~/ClassPing
git fetch origin
git switch ios/phase-14b-row-mapping
scripts/test-logic.sh     # expect 623 passing
scripts/test-store.sh     # expect 144 passing
git switch main && git merge --ff-only ios/phase-14b-row-mapping
```

Nothing to check on the phone: no screen changed. Applied on
`ios/phase-14b-row-mapping` by Claude; nothing merged into `main` or installed
by the agent.

## 6. Done when

- [ ] The GitHub checks on the branch are green (tests and ios-build).
- [ ] Your two scripts show 623 and 144.
- [ ] Merged into `main`.

## 7. If it breaks

- `cannot find 'instantFromServer' in scope` in the store tests: your
  `scripts/test-store.sh` is missing `Models+Rows` or `Logic/` wasn't copied;
  this branch's version has both.
- A `readsAMomentAsTheWebDoes` failure only for "2026-09-21T14:13:20": that
  case is skipped outside New York on purpose; a failure there means the
  phone's zone isn't what `TimeZone.current` says.
- The ios-build job fails but your laptop build works: GitHub's Xcode may be
  older than your Swift 6.4. Say so, and the check gets pinned or relaxed.
