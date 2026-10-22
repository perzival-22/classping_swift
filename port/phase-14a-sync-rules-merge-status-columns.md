---
title: "Phase 14a: the sync rules (merge, status, columns)"
date: 2026-10-22
---

# Phase 14a: the sync rules (merge, status, columns)

The first of Phase 14's five guides (D-89). It builds on your committed
`ba8b0a9` ("Phase 13b"), which is identical to the 13b reference: all four
files SAME, and your tree built. 14a touches only `Logic/` files and tests,
none of the five files in the 13b+ look pass, so you can type 13b+ and 14a in
either order (I checked them stacked too, see Verification).

**Your 13b phone check isn't recorded yet.** Before or after this guide, tell
me how steps 5 (cells copied from a spreadsheet app: did they arrive with
tabs?) and 6 (the import sheet and the class form closing together) went.

**What 14a is.** Sync is the riskiest thing in the app, so it starts with the
rules and no network at all: the three-way merge that decides what to keep
when the phone and the server disagree, the words the app may use about sync
("Synced" only after the server confirms), and the list of columns the app is
allowed to write. All three are ports of the web's own files, and every
answer is checked against what the web's functions printed. Nothing here
signs in, sends or receives anything.

**About testing on your real account (D-90).** You chose your real account
over a test one. I'd still rather you made a throwaway account, because a
merge bug on the first push can delete real rows, on the web too. Since it's
your call, from 14c on every guide starts read-only: the first pull only
compares and reports, a backup to Files and a web export come before the
first send, and the first send lists what it would write and waits for you.
14a needs none of that: it never touches the network.

**Start here:** three stops, one file each, each ending in a logic test run.
Stop 1 is the merge (4.1, 4.2), Stop 2 the sync words (4.3, 4.4), Stop 3 the
columns (4.5, 4.6). The test files are copied, not typed.

**Verification (2026-10-22):** the reference iOS build passed with no warnings. `logic-test.sh`: **613/613**
in the default zone, New York, Kolkata, London and Auckland (+45:
`MergeTests` 19, `SyncStatusTests` 9, `ColumnsTests` 17), with **587** after
Stop 1 and **596** after Stop 2 (throwaway copies with the later files left
out). `persistence-test.sh` **120/120** (no store file changed).
`doc-check-stack.sh`, the 13b+ guide then this one over your `ba8b0a9` tree:
8 files, IDENTICAL, `BUILD_OK` (the reference holds both, so that's the
check). Your own `scripts/test-logic.sh` and
`scripts/test-store.sh` in a throwaway copy of your tree with this guide's
blocks and the four test files: **613/613** and **132/132**.
Nothing here can be tried on a phone, because nothing here shows on one.

## 1. Goal

Nothing new on screen. This phase is the rule book sync will follow, and the
tests are the check: **613 logic tests passing**, 45 of
them new, many comparing with values the web printed. On the phone, the app
builds and runs exactly as before.

What the three files decide:

- **The merge (`Merge.swift`).** For every row, one of five outcomes: take
  the server's, keep the phone's and send it, keep a row made offline and
  send it, drop a row deleted on another device, or flag a conflict when
  both sides changed. It needs a fingerprint of each row as the server last
  confirmed it (the "snapshot"), and that fingerprint must match the web's
  bit for bit, because the same account syncs from both.
- **The sync words (`SyncStatus.swift`).** "Saved on this device",
  "Syncing…", "Synced", "Offline, 3 changes waiting", and the longer lines
  for Settings, word for word from the web, plus the retry waits and the
  error messages a student sees.
- **The columns (`Columns.swift`).** Which columns of each table the app
  writes. A batch sent to the server is trimmed so every row names the same
  columns, because the server blanks a column in any row that leaves out a
  column another row in the batch names.

## 2. New Swift concepts

### Numbers of a fixed size that wrap around

`Int` is 64 bits and stops the app if a sum or product goes past its limit.
`UInt32` is 32 bits with no sign, and the operators with an `&` in front
(`&*`, `&+`) wrap around instead of stopping: they keep the low 32 bits,
like a car's odometer rolling over. That's exactly what JavaScript's
`Math.imul` does, which the web's fingerprint uses.

```swift
let a: UInt32 = 4_000_000_000
let b = a &* 2           // 3_705_032_704: the low 32 bits of 8 billion
// let c = a * 2         // would stop the app: overflow
let bits = a ^ 0xFF      // ^ flips bits (XOR), as in JavaScript
let high = a >> 16       // shifts right, filling with zeros (JS >>>)
```

The fingerprint also reads a string as UTF-16 units, because JavaScript's
`charCodeAt` does. `"📚".utf16.count` is 2, while `"📚".count` is 1.

### Passing functions in

`mergeWithServer` works on any kind of row, so it can't know how to read a
row's id or turn it into text. The caller hands those in as functions. A
parameter's type can be a function type, written `(Input) -> Output`:

```swift
func longest<T>(_ items: [T], size: (T) -> Int) -> T? {
    items.max { size($0) < size($1) }
}
longest(["a", "abc"], size: { $0.count })   // "abc"
```

The `<T>` is the generic you met in Phase 4a; the new part is `size`, a
function that arrives as a value.

### A short name for a type, and changing what's inside a `Result`

`typealias ServerRow = [String: JSONValue]` gives a long type a short name;
the two are the same type. And `Result` (Phase 11a) has `map`, which changes
the success value and passes a failure through untouched:

```swift
let r: Result<[Int], MyError> = .success([4, 5])
let first = r.map { $0.first ?? 0 }   // .success(4); a .failure stays one
```

## 3. What it maps from the web

- **`lib/merge.ts` → `Logic/Merge.swift`.** Same five outcomes, same order
  (server rows first, then rows only the phone has), and a repeated id
  behaves as a JavaScript `Map` does: the first place, the last value. The
  web gets each row's id from `.id`; here the caller passes `id:` and
  `rowJSON:` in. The snapshot is saved as a `JSONValue` (the web uses
  `localStorage`), read back by the same rules: anything that isn't text is
  skipped, anything that isn't an object gives an empty snapshot.
- **`lib/sync.ts` → `Logic/SyncStatus.swift`.** Every word the same. Two
  small differences (D-91): at 30 days and older, "Last synced" shows the
  phone's own short date where the web shows the browser's, and a negative
  retry number waits the first delay (the web returns nothing; nothing calls
  it that way). The error functions take the error's message text, where the
  web digs the message out of whatever it was handed.
- **`lib/supabase/columns.ts` → `Logic/Columns.swift`.** Same lists, checked
  against the web's in order. A bad batch comes back as a `Result` failure
  instead of a thrown error, so there's no `do`/`catch` anywhere. A Swift
  dictionary has no order, so a trimmed row doesn't keep the column order;
  only the set of columns matters to the server.
- **Waiting for 14b:** the web's "the mappers and the column lists agree"
  tests need the row mapping (`lib/supabase/map.ts`), which is 14b's whole
  job. Until then the column tests use a hand-built task row.

Where the expected values come from: the web's own `merge.test.ts` and `columns.test.ts` cases are here as twins, all but the eight per-table "mappers and column lists agree" checks, which need the mapper (14b). `lib/sync.ts` has no test file on the web, so its tests compare with what the web's functions printed in Node 24 (`WebValues14a.swift`, written by `docs/ios/.scratch/p14a/gen.ts`), as do 16 fingerprints and the eight column lists.

## 4. Files, in the order to type them

### Stop 1: the merge

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/Merge.swift` (new file)

```swift

//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Merge.swift
//  Phase:   14a (the sync rules, before any network)
//  Ports:   lib/merge.ts (`hashRow`, `mergeWithServer`, `snapshotToJson`,
//           `snapshotFromJson`); its tests are lib/merge.test.ts
//
//  Summary: The three-way merge that decides, row by row, what to keep when
//           this phone and the server disagree. It needs a third thing, the
//           "snapshot": a short fingerprint of every row as it was the last
//           time the server confirmed it. With that, "on my phone but not on
//           the server" can be told apart: made here and never sent (keep and
//           send), or deleted somewhere else (drop). Nothing here touches the
//           network; Phase 14c uses it.
//

import Foundation

// MARK: - The fingerprint

/// A short fingerprint of some text, 53 bits wide, written in base 36. The
/// web's `hashRow` (cyrb53). Two copies of a row get the same fingerprint
/// only if they are the same text, so comparing fingerprints answers "did
/// this row change?" without keeping the whole row.
///
/// It must give the web's exact answers: a snapshot the web saved has to mean
/// the same thing here. So it follows JavaScript's arithmetic exactly:
/// - `Math.imul` multiplies two 32-bit numbers and keeps the low 32 bits.
///   Swift's `&*` (the wrapping multiply) on `UInt32` does the same.
/// - `charCodeAt` reads UTF-16 units, so an emoji is two steps, not one.
///   Swift's `utf16` view gives the same units.
/// - `>>>` shifts without a sign; `>>` on `UInt32` does too.
func hashRow(_ input: String) -> String {
    var h1: UInt32 = 0xdeadbeef
    var h2: UInt32 = 0x41c6ce57
    // Mix in one UTF-16 unit at a time, as the web's loop does.
    for unit in input.utf16 {
        let ch = UInt32(unit)
        h1 = (h1 ^ ch) &* 2654435761
        h2 = (h2 ^ ch) &* 1597334677
    }
    // Two finishing rounds. The second uses the first's new h1, in this order.
    h1 = ((h1 ^ (h1 >> 16)) &* 2246822507) ^ ((h2 ^ (h2 >> 13)) &* 3266489909)
    h2 = ((h2 ^ (h2 >> 16)) &* 2246822507) ^ ((h1 ^ (h1 >> 13)) &* 3266489909)
    // 21 bits of h2 above all 32 bits of h1 make the 53-bit number the web
    // prints with `toString(36)`: lower case digits and letters.
    let value = (UInt64(h2 & 2_097_151) << 32) + UInt64(h1)
    return String(value, radix: 36)
}

// MARK: - The merge

/// What happened to one row in the merge. The raw text is the web's.
enum MergeOutcome: String, Sendable {
    /// Both sides agree, or only the server moved: the server's row is taken.
    case server
    /// Only this phone moved: its row is kept, and it still needs sending.
    case local
    /// Made here and never sent: kept, and it still needs sending.
    case localNew = "local-new"
    /// Gone from the server since we last agreed: dropped from this phone.
    case removed
    /// Both sides moved on their own: the caller decides, both are handed back.
    case conflict
}

/// Both versions of a row that changed on both sides since the last agreement.
struct MergeConflict<T> {
    let id: String
    let local: T
    let server: T
}

/// The merge's answer: the rows to keep, which of them still need sending,
/// the rows both sides changed, and why each row went the way it did.
/// `<T>` stands for whatever kind of row is being merged (a task, a class).
struct MergeResult<T> {
    var merged: [T]
    /// Ids whose phone version differs from the server's and must be sent.
    var pending: [String]
    var conflicts: [MergeConflict<T>]
    /// Per-id outcome: the merge's reasoning, kept for tests and diagnostics.
    var outcomes: [String: MergeOutcome]
}

/// Merges the server's rows into this phone's, using the snapshot as the
/// common ancestor. `rowJSON` turns a row into the text that gets
/// fingerprinted; `id` reads a row's id.
///
/// | on server | on phone | snapshot | result |
/// |---|---|---|---|
/// | yes | yes | matches the phone's row | the server's row (no local edit) |
/// | yes | yes | differs from the phone's | the phone's row, to send; if the server moved too, a conflict |
/// | yes | no | any | the server's row (another device made it) |
/// | no | yes | absent | keep and send (made here, never sent) |
/// | no | yes | present | drop (it was deleted or purged elsewhere) |
///
/// The last row stops a long-offline phone from bringing back everything it
/// deleted, which is why the snapshot is saved on the phone and survives a
/// close. A server row comes first in the order, then rows only the phone has.
func mergeWithServer<T>(
    _ local: [T],
    _ server: [T],
    snapshot: [String: String],
    id: (T) -> String,
    rowJSON: (T) -> String
) -> MergeResult<T> {
    // The web builds a Map from each list: a later row with the same id
    // replaces an earlier one, but keeps the earlier one's place in line.
    var localByID: [String: T] = [:]
    var localOrder: [String] = []
    for item in local {
        let key = id(item)
        if localByID[key] == nil { localOrder.append(key) }
        localByID[key] = item
    }
    var serverByID: [String: T] = [:]
    var serverOrder: [String] = []
    for item in server {
        let key = id(item)
        if serverByID[key] == nil { serverOrder.append(key) }
        serverByID[key] = item
    }

    // Server order first, then anything only the phone has, so the list
    // doesn't shuffle on every merge.
    var ids = serverOrder
    for key in localOrder where serverByID[key] == nil {
        ids.append(key)
    }

    var merged: [T] = []
    var pending: [String] = []
    var conflicts: [MergeConflict<T>] = []
    var outcomes: [String: MergeOutcome] = [:]

    for key in ids {
        let mine = localByID[key]
        let theirs = serverByID[key]
        let base = snapshot[key]

        if let theirs, mine == nil {
            // Only the server has it: another device made it.
            merged.append(theirs)
            outcomes[key] = .server
        } else if let mine, theirs == nil {
            if base == nil {
                // Never reached the server. This is the offline-made row the
                // web's old "replace everything" threw away.
                merged.append(mine)
                pending.append(key)
                outcomes[key] = .localNew
            } else {
                // We agreed it existed; the server says it doesn't any more.
                outcomes[key] = .removed
            }
        } else if let mine, let theirs {
            let mineHash = hashRow(rowJSON(mine))
            let theirsHash = hashRow(rowJSON(theirs))
            if mineHash == theirsHash {
                // The same row on both sides, whatever the snapshot says.
                merged.append(theirs)
                outcomes[key] = .server
            } else if let base {
                let localMoved = mineHash != base
                let serverMoved = theirsHash != base
                if localMoved && serverMoved {
                    conflicts.append(MergeConflict(id: key, local: mine, server: theirs))
                    merged.append(theirs)
                    outcomes[key] = .conflict
                } else if localMoved {
                    merged.append(mine)
                    pending.append(key)
                    outcomes[key] = .local
                } else {
                    merged.append(theirs)
                    outcomes[key] = .server
                }
            } else {
                // No common ancestor for a row both sides have: made apart
                // under one id, or the snapshot was lost. The server's row
                // holds the place; ours comes back as the other side.
                conflicts.append(MergeConflict(id: key, local: mine, server: theirs))
                merged.append(theirs)
                outcomes[key] = .conflict
            }
        }
    }

    return MergeResult(merged: merged, pending: pending, conflicts: conflicts, outcomes: outcomes)
}

// MARK: - Keeping the snapshot

/// The snapshot as JSON, for saving on the phone. The web's `snapshotToJson`.
func snapshotToJSON(_ snapshot: [String: String]) -> JSONValue {
    .object(snapshot.mapValues { JSONValue.string($0) })
}

/// The snapshot back from saved JSON. A missing, damaged or wrong-shaped
/// value gives an empty snapshot, and any entry that isn't text is skipped,
/// as the web's `snapshotFromJson` does. `compactMapValues` keeps only the
/// values the closure turns into something other than nil.
func snapshotFromJSON(_ raw: JSONValue?) -> [String: String] {
    guard case .object(let object)? = raw else { return [:] }
    return object.compactMapValues { $0.stringValue }
}
```

### 4.2 Stop 1 check: the merge tests (copy, don't type)

```bash
cd ~/ClassPing
R=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $R/Logic/WebValues14a.swift Tests/Logic/
cp $R/Logic/MergeTests.swift Tests/Logic/
scripts/test-logic.sh     # expect 587 tests passing
```

`WebValues14a.swift` holds what the web printed for all three stops; it
comes first so the merge tests can read it. If `hashMatchesTheWebExactly`
fails, the message shows the input: a mismatch on everything points at the
two finishing lines (the second must use the first's new `h1`), a mismatch
only on the emoji input points at `utf16` (it must not be `unicodeScalars`).

### Stop 2: the sync words

### 4.3 `~/ClassPing/Sources/ClassPing/Logic/SyncStatus.swift` (new file)

```swift

//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/SyncStatus.swift
//  Phase:   14a (the sync rules, before any network)
//  Ports:   lib/sync.ts (`SyncState`, `SyncStatus`, `IDLE_STATUS`,
//           `RETRY_DELAYS_MS`, `retryDelay`, `syncLabel`, `syncDetail`,
//           `relativeTime`, `isAuthError`, `describeSyncError`)
//
//  Summary: What the app is allowed to say about where your work has got to.
//           The one rule everything here follows: never say "Synced" before
//           the server has confirmed. The words come straight from the web.
//           Nothing here touches the network; Phase 14c drives it.
//

import Foundation

// MARK: - The states

/// Where things stand, weakest true statement first. "Saved" is always true,
/// because the phone writes every change to its own storage before any
/// network call. The raw text is the web's.
enum SyncState: String, Sendable {
    /// Written to this phone. Nothing sent yet, or there's no account.
    case saved
    /// A send is under way. The phone's copy is safe; the server hasn't said yes.
    case syncing
    /// The server has confirmed everything this phone has.
    case synced
    /// Known to be offline, with changes waiting.
    case offline
    /// A send failed for a reason trying again may not fix. The student should know.
    case error
}

/// One snapshot of the sync state, with the numbers the words need.
struct SyncStatus: Equatable, Sendable {
    var state: SyncState
    /// When the server last confirmed, in milliseconds since 1970 (the web's
    /// `Date.now()`), or nil if this phone never has. Saved across relaunches.
    var lastSyncedAt: Double?
    /// How many records have changes the server hasn't confirmed.
    var pending: Int
    /// Only in the `error` state. Written for a student, not a developer.
    var error: String?

    /// Nothing sent, nothing waiting. The web's `IDLE_STATUS`.
    static let idle = SyncStatus(state: .saved, lastSyncedAt: nil, pending: 0, error: nil)
}

// MARK: - Trying again

/// How long to wait before each retry of a failed send, in milliseconds.
/// Starts fast (most failures are a dropped connection already back) and
/// tops out at half a minute. The web's `RETRY_DELAYS_MS`.
let RETRY_DELAYS_MS = [1_000, 3_000, 8_000, 20_000, 30_000]

/// The wait before retry number `attempt` (0 is the first), staying at the
/// last delay after that. A negative attempt counts as the first; the web
/// would return nothing there, and nothing calls it that way.
func retryDelay(_ attempt: Int) -> Int {
    RETRY_DELAYS_MS[min(max(attempt, 0), RETRY_DELAYS_MS.count - 1)]
}

// MARK: - The words

/// Short label for the status chip. The web's `syncLabel`.
func syncLabel(_ status: SyncStatus) -> String {
    switch status.state {
    case .saved:
        return "Saved on this device"
    case .syncing:
        return "Syncing\u{2026}"
    case .synced:
        return "Synced"
    case .offline:
        return status.pending > 0
            ? "Offline, \(status.pending) change\(status.pending == 1 ? "" : "s") waiting"
            : "Offline"
    case .error:
        return status.error ?? "Sync problem"
    }
}

/// The longer line for Settings: where the data actually is in each state.
/// The web's `syncDetail`. `now` is a parameter so tests can fix the clock.
func syncDetail(_ status: SyncStatus, now: Date = Date()) -> String {
    switch status.state {
    case .saved:
        return status.pending > 0
            ? "Your changes are on this device. They'll go to the cloud when you're signed in and online."
            : "Your work is saved on this device."
    case .syncing:
        return "Sending your latest changes\u{2026}"
    case .synced:
        if let at = status.lastSyncedAt {
            return "Everything is backed up. Last synced \(relativeTime(at, now: now))."
        }
        return "Everything is backed up."
    case .offline:
        if let at = status.lastSyncedAt {
            return "You're offline. Changes are safe on this device and will sync automatically. Last synced \(relativeTime(at, now: now))."
        }
        return "You're offline. Changes are safe on this device and will sync when you reconnect."
    case .error:
        return "\(status.error ?? "Something went wrong syncing.") Your work is still saved on this device."
    }
}

/// "just now", "6 minutes ago", "yesterday": enough precision to be useful.
/// The web's `relativeTime`. `at` is in milliseconds since 1970.
///
/// JavaScript's `Math.round` and Swift's `rounded()` agree on every number
/// here (they differ only on negative halves, and the gap is never negative
/// after the `max(0, ...)`). From 30 days on the web prints the browser's
/// date; this prints the phone's own short date, so that one line is
/// worded by the device on purpose (D-91).
func relativeTime(_ at: Double, now: Date = Date()) -> String {
    // The web works in whole milliseconds, so round the clock to match.
    let nowMS = (now.timeIntervalSince1970 * 1000).rounded()
    let secs = max(0, ((nowMS - at) / 1000).rounded())
    if secs < 45 { return "just now" }
    let mins = Int((secs / 60).rounded())
    if mins < 60 { return "\(mins) minute\(mins == 1 ? "" : "s") ago" }
    let hours = Int((Double(mins) / 60).rounded())
    if hours < 24 { return "\(hours) hour\(hours == 1 ? "" : "s") ago" }
    let days = Int((Double(hours) / 24).rounded())
    if days == 1 { return "yesterday" }
    if days < 30 { return "\(days) days ago" }
    let date = Date(timeIntervalSince1970: at / 1000)
    return date.formatted(date: .numeric, time: .omitted)
}

// MARK: - Errors

/// Is this the kind of failure a fresh sign-in token can fix? A JWT or 401
/// from Supabase almost never means the account is gone: Clerk can mint a new
/// token quietly, so the app refreshes and retries instead of asking the
/// student to sign in. The web's `isAuthError`. Takes the error's message
/// text (the web digs the message out of whatever it was handed).
func isAuthError(_ message: String) -> Bool {
    let lower = message.lowercased()
    return lower.contains("jwt") || lower.contains("401") || lower.contains("unauthor")
}

/// Turns a failure's message into something a student can act on. Most sync
/// failures aren't the student's fault and aren't dressed up as one; the
/// actionable ones (an expired session, no room left) get their own words.
/// The web's `describeSyncError`.
func describeSyncError(_ message: String) -> String {
    let lower = message.lowercased()
    if lower.contains("jwt") || lower.contains("401") || lower.contains("unauthor") {
        return "Your session expired. Sign in again to keep syncing."
    }
    if lower.contains("quota") || lower.contains("storage") || lower.contains("full") {
        return "There's no room left to save more. Free some space and try again."
    }
    if lower.contains("row-level security") || lower.contains("policy") {
        return "This account isn't allowed to save that. Sign out and back in."
    }
    if lower.contains("fetch") || lower.contains("network") {
        return "Couldn't reach the server."
    }
    return "Couldn't save your latest changes to the cloud."
}
```

### 4.4 Stop 2 check: the status tests (copy, don't type)

```bash
cd ~/ClassPing
R=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $R/Logic/SyncStatusTests.swift Tests/Logic/
scripts/test-logic.sh     # expect 596 tests passing
```

Type the `…` in "Syncing\u{2026}" exactly as written (`\u{2026}` is the
single ellipsis character); three dots won't match the web.

### Stop 3: the columns

### 4.5 `~/ClassPing/Sources/ClassPing/Logic/Columns.swift` (new file)

```swift

//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Columns.swift
//  Phase:   14a (the sync rules, before any network)
//  Ports:   lib/supabase/columns.ts (`TABLE_COLUMNS`, `TZ_COLUMNS`,
//           `ColumnContractError`, `scopeRows`, `scopeRow`, `pickColumns`);
//           its tests are lib/supabase/columns.test.ts
//
//  Summary: The columns this app writes, per table, written down once. When
//           several rows go to the server in one batch, the server writes
//           every column any row names, and a row that left one out gets it
//           blanked. So every batch is trimmed to the same columns first, and
//           a column some row lacks is left out of the whole batch: "don't
//           touch it" is always safer than "erase it".
//

import Foundation

// MARK: - The tables and their columns

/// The tables the app writes. The raw text is the table's name on the server.
enum ScopedTable: String, CaseIterable, Sendable {
    case classes
    case tasks
    case grades
    case notes
    case taskPlans = "task_plans"
    case studySessions = "study_sessions"
    case profiles
    case gameState = "game_state"

    /// The columns this app owns in the table, in the web's order. `rev` and
    /// `updated_at` are never here: the database owns those. Nor is
    /// `profiles.tz`, which goes in its own two-column write (`TZ_COLUMNS`).
    /// The web's `TABLE_COLUMNS`; the tests check every list against it.
    var columns: [String] {
        switch self {
        case .classes:
            return ["id", "user_id", "name", "short", "color", "days",
                    "additional_meetings", "start_min", "end_min", "remind_before",
                    "alarm", "extra_reminders", "credits", "room", "instructor",
                    "notes", "term", "archived", "goal", "source_feed", "source_uid",
                    "source_hash", "deleted_at"]
        case .tasks:
            return ["id", "user_id", "class_id", "title", "due", "due_time",
                    "reminder", "done", "kind", "notes", "subtasks", "remind_leads",
                    "snoozed_until", "repeat_rule", "repeat_until",
                    "recurrence_parent_id", "source_feed", "source_uid",
                    "source_hash", "deleted_at"]
        case .grades:
            return ["id", "user_id", "class_id", "title", "score", "max", "weight",
                    "date", "kind", "deleted_at"]
        case .notes:
            return ["id", "user_id", "class_id", "date", "title", "body", "task_id",
                    "deleted_at"]
        case .taskPlans:
            return ["id", "user_id", "task_id", "date", "priority"]
        case .studySessions:
            return ["id", "user_id", "task_id", "class_id", "minutes",
                    "completed_at", "mode"]
        case .profiles:
            return ["user_id", "username", "avatar_url", "theme", "accent", "style",
                    "post_class_nudge", "quiet_start", "quiet_end", "finals_date",
                    "grade_scale", "term_start", "term_end", "term_name",
                    "term_setup_prompted", "import_feeds", "custom_scale", "quotes"]
        case .gameState:
            return ["user_id", "data"]
        }
    }

    /// Columns a row can't go without. With no `id` the server can't match the
    /// row, and with no `user_id` it refuses it, so these two are the cases
    /// where quietly leaving the column out isn't safe. The web's `REQUIRED`.
    var required: [String] {
        switch self {
        case .profiles, .gameState:
            return ["user_id"]
        default:
            return ["id", "user_id"]
        }
    }
}

/// The phone's time zone write: these two columns and nothing else, so it
/// never touches the rest of the profile. The web's `TZ_COLUMNS`.
let TZ_COLUMNS = ["user_id", "tz"]

// MARK: - Trimming a batch

/// Why a batch couldn't be trimmed. The web throws a `ColumnContractError`;
/// here it comes back inside a `Result`, as in 11a, so no `do`/`catch`.
enum ColumnContractError: Error, Equatable, Sendable {
    /// A row is missing `column`, which can't safely be left out.
    case missingRequired(table: ScopedTable, column: String)

    /// The web's message, word for word.
    var message: String {
        switch self {
        case .missingRequired(let table, let column):
            return "\(table.rawValue): a row is missing \(column), which is not safe to omit"
        }
    }
}

/// One row on its way to the server: column name to value. A column that
/// isn't in the dictionary is the web's `undefined` (leave it alone); a
/// `.null` value is the web's `null` (write an empty value). That difference
/// is how a restore clears `deleted_at`.
typealias ServerRow = [String: JSONValue]

/// Trims a batch to the columns this app owns. Every row comes back with the
/// same columns; anything undeclared is dropped; a declared column that any
/// row is missing is dropped from every row (so the server keeps its value).
/// A row without a required column fails the whole batch. An empty batch
/// stays empty. The web's `scopeRows`.
///
/// One difference: a Swift dictionary has no order, so the rows don't keep
/// the declared column order. Only the set of columns matters to the server.
func scopeRows(_ table: ScopedTable, _ rows: [ServerRow]) -> Result<[ServerRow], ColumnContractError> {
    if rows.isEmpty { return .success([]) }

    // A required column that's missing or null fails the batch. The web checks
    // each required column across every row in this order, so the error names
    // the same column the web's would.
    for column in table.required {
        let missing = rows.contains { row in
            row[column] == nil || row[column] == JSONValue.null
        }
        if missing {
            return .failure(.missingRequired(table: table, column: column))
        }
    }

    // The columns every row actually carries (a `.null` counts as carried).
    let effective = table.columns.filter { column in
        rows.allSatisfy { $0[column] != nil }
    }

    // Each row keeps exactly those columns.
    let scoped = rows.map { row in
        var out: ServerRow = [:]
        for column in effective {
            out[column] = row[column]
        }
        return out
    }
    return .success(scoped)
}

/// One row, same rules. For the two one-row tables (profiles, game_state).
/// The web's `scopeRow`.
func scopeRow(_ table: ScopedTable, _ row: ServerRow) -> Result<ServerRow, ColumnContractError> {
    scopeRows(table, [row]).map { $0.first ?? [:] }
}

/// Picks only the given columns from one row, for a write that touches a
/// few columns on purpose (the time zone write). A column the row doesn't
/// have is left out rather than sent empty. The web's `pickColumns`.
func pickColumns(_ row: ServerRow, _ columns: [String]) -> ServerRow {
    var out: ServerRow = [:]
    for column in columns {
        if let value = row[column] {
            out[column] = value
        }
    }
    return out
}
```

### 4.6 Stop 3 check: the column tests (copy, don't type)

```bash
cd ~/ClassPing
R=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $R/Logic/ColumnsTests.swift Tests/Logic/
scripts/test-logic.sh     # expect 613 tests passing
```

`everyTableMatchesTheWebInOrder` compares each list with the web's, so a
typo in a column name fails there and names the table.

## 5. Run it

```bash
cd ~/ClassPing
scripts/test-logic.sh     # expect 613
scripts/test-store.sh     # expect 132 (unchanged)
xtool dev build
xtool dev
```

The last command installs on your phone, so run that one yourself.

1. **Nothing changed:** the app opens on Today as before, and Tasks, Notes
   and Profile work. 14a adds no screen and asks for no network.

**Report back:** the two test counts, and that the app still opens. Then
14b (the row mapping).

Nothing was committed or installed by the agent.

## 6. Done when

- [ ] `scripts/test-logic.sh` passes 613 tests (587 after Stop 1, 596 after Stop 2)
- [ ] `scripts/test-store.sh` still passes 132
- [ ] `xtool dev build` has no errors or warnings
- [ ] The app opens and works as before

## 7. If it breaks

- **`Integer literal '2654435761' overflows when stored into 'Int32'`.** `h1`
  or `h2` was declared `Int32`. They're `UInt32`.
- **A test run that stops with "Arithmetic overflow".** A `*` where the
  guide has `&*` in `hashRow`.
- **`hashMatchesTheWebExactly` fails on every input.** Check the two
  finishing lines in order: `h1` first, then `h2` using the new `h1`, and
  `>> 16` / `>> 13` in the right places.
- **It fails only on the emoji inputs.** `input.utf16` became
  `input.unicodeScalars` or the string itself.
- **`Cannot find 'WEB_HASHES' in scope`** (or another `WEB_` name). Copy
  `WebValues14a.swift` (4.2).
- **`labelsAndDetailsMatchTheWeb` fails on "Syncing".** Three dots typed
  instead of `\u{2026}`.
- **`Referencing operator function '==' on 'Result' requires...`.**
  `ColumnContractError` lost its `Equatable`.
- **`Variable 'out' was never mutated` or similar warnings.** A `var` typed
  as `let` or the reverse; compare the line with the guide.
