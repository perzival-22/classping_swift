---
title: "ClassPing iOS: progress"
date: 2026-10-21
generated_by: skills-for-architects
---

# ClassPing iOS: progress

*Update at the end of every session. Start every session by reading IOS_APP.md, this file and the current phase file, then listing `~/ClassPing/Sources/ClassPing/`.*

## Current handoff (2026-10-22, 08:38)

This section supersedes the "08:40" handoff below, kept as history.

- **First phone run (08:28):** Continue with Google failed with Clerk's
  "redirect url ... does not match an authorized redirect URI" for
  `XTL-V6P7S9UKM7.space.classping.ios://callback`. xtool installs the app as
  `XTL-<team>.space.classping.ios` and ClerkKit built its default redirect
  from that. Kelvin's dashboard is set up right (Native API on,
  `space.classping.ios://callback` allowlisted, no iOS app registered, which
  OAuth doesn't need).
- **Fixed (D-102, `91dee1f` on `ios/phase-14cd-sign-in-and-sync`):**
  `Account.configure()` pins the redirect and callback scheme to
  `space.classping.ios`. Run 39779640677 green: logic **633/633**, store
  **154/154** on Swift 6.4.1, iOS build on Xcode 26.6. Not tried on a phone.
- **Phone, 08:43 (Kelvin, after pulling the fix):** "Worked, all classes
  from supabase are in the app, my profile, theme. and the redirect worked."
  So step 1 (Google sign-in comes back to the app) passed, and the pull from
  the web reached the phone (classes, profile, theme). **Not reported yet:**
  whether the backups (step 3) were made before Sync now, the review's
  counts (step 2), the card ending on "Synced", and anything going the other
  way: a phone change reaching the web (steps 5 and 6), a web change showing
  on return (7), offline (8). D-95's owed 13b and 13b+ steps still open.
- **Next for Kelvin:** section 5, steps 5 to 9. Don't merge yet.
- **Next for Claude:** record those results; then unchanged from 08:40.

## Current handoff (2026-10-22, 08:40)

This section supersedes the "02:40" handoff below, kept as history.

- **14b: not merged yet** (`main` is still `5daaae6`). Still ready.
- **14cd step 2 pushed** (`fcd664f` on `ios/phase-14cd-sign-in-and-sync`):
  Google sign-in (`Sync/Account.swift`), the transport
  (`Sync/SupabaseTransport.swift`), the engine (`Sync/SyncEngine.swift`),
  the merge and push (`Store+Sync.swift`, `Logic/SyncPlan.swift`), the Account
  card and the first-sync review on the Profile tab. Change note:
  [phase-14cd-sign-in-and-sync.md](phase-14cd-sign-in-and-sync.md). How it
  syncs: D-101 (first sync waits for the review and his tap; Realtime left
  out, pull on return instead).
- **Checks:** GitHub run 39775758716 green: logic **633/633**, store
  **154/154** on Swift 6.4.1, iOS build on Xcode 26.6. His xtool built it on
  the laptop (throwaway clone, 95 s). **Nothing has run on a phone.**
- **From Kelvin:** the full anon key arrived 07:55 (role `anon`, in
  `Sync/SyncConfig.swift` with the other two public values). The Claude app
  now reads `perzival-22/ClassPing` (clone at `/home/claude/classping` in a
  cloud session; GitHub `main` is `818e2fd`, 2026-10-19, which may trail his
  laptop's uncommitted web work). **Still his:** the Clerk Dashboard step
  (Native API on, `space.classping.ios://callback` allowlisted).
- **Next for Kelvin:** the note's section 5, steps 1 to 9, on his own Google
  account, backups first. Ask for the review's counts (step 2) and any words
  under the button or in the sync row.
- **Next for Claude:** fix whatever the phone shows; then 14e (the signed-in
  server calls) on its own branch from 14cd; Realtime later if wanted.

## Current handoff (2026-10-22, 02:40)

This section supersedes the "01:55" handoff below, kept as history. Read it
from the newest branch: `ios/phase-14cd-sign-in-and-sync`.

- **14b is ready to merge:** `ios/phase-14b-row-mapping`, every check green
  (Linux logic 623 and store 144 on Swift 6.4.1; iOS build on Xcode 26.6).
  Kelvin: `git fetch && git switch main && git merge --ff-only
  origin/ios/phase-14b-row-mapping`. Nothing to check on the phone.
- **CI false failure, fixed:** the iOS step's annotation `grep` ended the step
  when a successful build had no error line (pipefail), so a green build
  showed red (run 39730111732 on 14b, 39730367136 on 14cd). Fixed in
  `checks.yml` on both branches; 14cd merges 14b so both fast-forward in order.
- **14cd started (D-100):** branch `ios/phase-14cd-sign-in-and-sync`, stacked
  on 14b. Step 1 adds the SDKs (`Package.swift`, `Vendor/clerk-ios` from the
  updated `port/tools/vendor-clerk.sh`). Builds on GitHub's Xcode 26.6 and on
  the laptop's xtool (throwaway clone, 71 s). No app code uses them yet.
  **Don't merge 14cd until the phase is done.**
- **Next session, 14cd step 2 onward,** in the order of
  [phase-14cd-plan.md](phase-14cd-plan.md): Info.plist URL type,
  `Sync/SyncConfig.swift`, `Sync/Auth.swift`, the Supabase client (check the
  `accessToken` option in supabase-swift 2.55.4's source first), snapshot and
  `Store+Sync.swift` with store tests on a fake transport, Realtime, the
  account card and the first-sync review.
- **Still needed from Kelvin** (none blocks step 2 to the store tests): the
  full Supabase anon key; `space.classping.ios://callback` in Clerk Dashboard
  > Native applications (and the Native API on); read access for the Claude
  app to `perzival-22/ClassPing` (the cloud can't read `lib/` without it; the
  plan already summarizes the sync code).
- **Laptop scratch from this session:** `docs/ios/.scratch/p14b/`
  (`gen.ts`, `copylib.py`, `weblib/`, `verify.sh`, `zones.sh`,
  `kelvin14b.sh`, `out/`) and `.scratch/p14cd/xtool-branch.sh` (builds any
  pushed branch with xtool in a throwaway clone). Safe to delete from WSL.

## Current handoff (2026-10-22, 01:55)

This section supersedes the "01:25" handoff below, kept as history.
**This file in the Swift repo (`port/PROGRESS.md`) is now the one to update
(D-98).** The laptop's `docs/ios/PROGRESS.md` stops at 01:25.

- **New flow (D-98):** Claude pushes each phase to its own `ios/<phase>`
  branch of `perzival-22/classping_swift`; GitHub Actions
  (`.github/workflows/checks.yml`) runs `scripts/test-logic.sh` and
  `scripts/test-store.sh` on Linux and an unsigned iOS build on a Mac. Kelvin
  pulls, tries it on the phone, and merges with `--ff-only`. The cloud session
  has no Swift and can't reach download.swift.org: read the CI result
  (`gh run list --branch <branch>`, `gh run view <id> --log-failed`) instead
  of claiming a check ran; job logs can't be downloaded from the cloud, so
  the workflow echoes compiler errors and test totals as annotations, which
  `gh run view <id>` shows. First runs: Xcode 16.4 (`macos-15`) refused
  `ClassPingApp.swift:131` (the notification delegate's sendability), which
  the laptop's newer SDK accepts, so `ios-build` runs on `macos-26` with its
  newest Xcode (26.6 on 2026-10-22), and passes.
- **14b written, verified and pushed** (`ios/phase-14b-row-mapping`, two
  commits on `5daaae6`: port docs and CI, then the phase). Change note:
  [phase-14b-row-mapping.md](phase-14b-row-mapping.md). New
  `Models+Rows.swift` and `Logic/ServerValues.swift`; `scripts/test-store.sh`
  copies `Models+Rows`. Differences from the web: D-99.
- **14b verification (laptop, before the push):** reference `BUILD_OK`, no
  warnings; logic **623/623** in the default zone, New York, Kolkata, London
  and Auckland; reference store **132/132**; his scripts on a throwaway copy
  of his tree with the files laid over **623/623** and **144/144**, Sources
  equal to the reference. "web:" values from map.ts itself in node 24
  (laptop `docs/ios/.scratch/p14b/gen.ts` over a copy of the lib modules made
  by `copylib.py`).
- **Not merged, nothing on the phone to check** (no screen changed).
- **Account (D-97):** first sync on Kelvin's own Google account, D-90's
  guards first.
- **Next: 14cd**, planned in [phase-14cd-plan.md](phase-14cd-plan.md) from
  the web store's own sync code (hydrate, flush, Realtime, deletes) with the
  guards built into the app. Needs from Kelvin: the full Supabase anon key (what he
  pasted stops after the JWT header) and `space.classping.ios://callback` in
  Clerk Dashboard > Native applications > "Allowlist for mobile SSO redirect"
  (the bundle ID is `space.classping.ios`, from `xtool.yml`). Before writing
  it: clone the web repo read-only for `lib/` (`perzival-22/ClassPing`), run
  `port/tools/vendor-clerk.sh` (needs a shell that can reach GitHub; it
  doesn't need Swift), and add a Package.swift change; the iOS build of
  ClerkKit itself was only proven under xtool on the laptop (D-96), so the
  first 14cd push shows whether GitHub's Xcode builds it too.
- **Phone steps owed** (the batch after 14cd): 13b steps 5 and 6; 13b+ steps
  5 to 10.

## Current handoff (2026-10-22, 01:25)

This section supersedes the "00:45" handoff below, kept as history. 14b is
being written in this same session; if this is still the top handoff, 14b
did not finish (look in `.scratch/p14b/` and the reference for what landed).

- **The plan changed (D-92 to D-97).** The app has a deadline a few days out;
  everything but 12 is in scope (14, 15, 16). From 14b Claude applies each
  verified phase on a branch with `tools/apply-phase.sh` and Kelvin reviews and
  merges (D-93; IOS_APP.md 3.2 rewritten). Guides are change notes. 14's rest
  is three guides: 14b, 14cd, 14e (D-95). Phone checks are batched: after
  14cd, after 15, after 16. `nativex-gold/` is frozen until 16 lands.
- **13b+ and 14a typed and committed together** (`5daaae6`, "Phase 14a",
  00:31). `review-stack.sh`: 14a's three files differ from the guide only by a
  leading blank line; 13b+'s five match with blank lines ignored; his Sources
  equal the reference (blank lines ignored); his tree `BUILD_OK`. 14a and
  13b+ are the last phases Kelvin typed.
- **`tools/apply-phase.sh`** tested on a clone of his repo at `ba8b0a9`:
  13b+ rehearsed (guide's files IDENTICAL, his scripts 568 and 132, iOS
  `BUILD_OK`), committed on `ios/phase-13b-plus-...`, clone back on `main`.
  Its stacked mode (`[base]` = an unmerged branch) is not yet confirmed: the
  computer went offline mid-test. Test it on a clone before first use.
- **Spike 1 (D-96):** supabase-swift 2.55.4 builds as is; clerk-ios 1.6.1
  fails as is (xtool can't run `xcstringstool` for String Catalogs) and
  builds as a copy with them converted (`tools/vendor-clerk.sh`, written, not
  yet run on its own); ClerkKitUI fails (asset catalog needs `actool`).
  Logs in `.scratch/sprint/spike1*.log`. Builds only, nothing ran on a phone.
- **What Kelvin gave for 14cd (01:10):** the Clerk publishable key
  (`pk_live_...`, the production instance at clerk.classping.space), the
  Supabase URL (`https://hrrcgquguauzyfhgednz.supabase.co`), Google as the
  sign-in method. **Still needed:** the full Supabase anon key (what he pasted
  stops after the JWT header), and, for Google on a production instance, the
  app's `<bundle id>://callback` in Clerk Dashboard > Native applications >
  "Allowlist for mobile SSO redirect" (send him the exact string once the
  bundle ID is read from `~/ClassPing/xtool.yml`). No server secret belongs
  in this repo or the app (IOS_APP.md 3.3); this repo is public.
- **Account (D-97):** the first sync uses his own Google account, with D-90's
  guards first (backup and web export, read-only first pull, dry run).
- **Phone steps owed** (asked in the batch after 14cd): 13b steps 5 and 6;
  13b+ steps 5 to 10.
- **Scratch:** `docs/ios/.scratch/sprint/` (spike and apply tests) and
  `docs/ios/.scratch/p14b/` (`copylib.py`, `weblib/`, `gen.ts`). Safe to
  delete from WSL once 14b is recorded.

## Current handoff (2026-10-22, 00:45)

This section supersedes the "10:40" handoff below, kept as history.

- **13b typed and committed** (`ba8b0a9`, "Phase 13b"), working tree clean.
  `review-stack.sh phase-13b-…`: all four files SAME, his tree `BUILD_OK`.
  His own suites were **not** re-run this session. His phone steps 5
  (spreadsheet cells arriving with tabs) and 6 (the import sheet and the class
  form closing together) are **not yet reported**; ask first.
- **13b+ written** (a look pass, Kelvin's list for the Profile banner and the
  theme pills, from a screenshot of the app, not the web):
  [phase-13b-plus-profile-banner-and-theme-pills.md](phase-13b-plus-profile-banner-and-theme-pills.md).
  Three new files (`Design/Theme+Pills.swift`, `Screens/Profile/PillPicker.swift`,
  `Screens/Profile/ProfileBanner.swift`), two replaced
  (`Screens/ProfileView.swift`, `Screens/Profile/ProfileCard.swift`), two
  stops (pills, then banner). No test or script changes.
- **Decisions:** D-86 (the banner: blurred photo, gradient fallback, rounded
  square photo, fade, name as text, pencil), D-87 (a custom banner upload
  waits for Phase 14), D-88 (the pills; contrast measured: dark text on
  Baby Pink must be `#26232A`, not `Theme.ink`; Ocean uses `#2A6BA8`).
- **Verification:** reference `BUILD_OK`, no warnings. `doc-check.sh
  phase-13b-plus-…`: 5 files, IDENTICAL, `BUILD_OK`. No Logic or Store file
  changed, so logic 568 and store 120 stand (not re-run). Contrast numbers by
  script (`.scratch/p13bplus/` and the table in the guide).
- **Not tried, can't be here:** anything visual. No simulator or phone was
  available, so the banner's layout, the blur edge, the fade on a bright photo,
  the keyboard hand-off after the pencil (`.onAppear { typing = true }`) and
  large text are all unseen. Guide steps 5 to 10 are the ones to report.
- **Web additions for after the app (D-78, D-87):** a profile banner on the
  web, if wanted, and the custom banner upload (field, route, deletion sweep,
  privacy line).
- **Phase 14 split (D-89):** Kelvin picked five guides, logic first, and no
  web change unless a route refuses a Bearer token. 14a merge, status and
  columns; 14b row mapping (map.ts is 551 lines, so it left 14a); 14c spikes
  and sign-in; 14d push, pull, tombstones and Realtime; 14e the server calls.
- **Real account (D-90):** Kelvin chose his real account over a test one.
  Claude still recommends a throwaway account. From 14c: read-only first
  pull, backups first, a dry run before the first send.
- **The 14a guide:** [phase-14a-sync-rules-merge-status-columns.md](phase-14a-sync-rules-merge-status-columns.md).
  Three new files (`Logic/Merge.swift`, `Logic/SyncStatus.swift`,
  `Logic/Columns.swift`) in three stops; copy four test files
  (`WebValues14a`, `MergeTests`, `SyncStatusTests`, `ColumnsTests`); no
  script changes. Independent of 13b+ (no shared file).
- **14a verification:** reference `BUILD_OK`, no warnings. `logic-test.sh`
  **613/613** in the default zone, New York, Kolkata, London and Auckland
  (+45); 587 after Stop 1, 596 after Stop 2. `persistence-test.sh`
  **120/120**. `doc-check-stack.sh` 13b+ then 14a: 8 files, IDENTICAL,
  `BUILD_OK` (14a alone differs from the reference only in 13b+'s files).
  His suites in a throwaway copy with both guides and the four test files:
  **613/613** and **132/132**. "web:" values from the web's own
  functions in node 24 (`.scratch/p14a/gen.ts` writes `WebValues14a.swift`).
- **Found on the way (D-91):** just under 30 days rounds to 30 in
  `relativeTime`, so the web prints the browser's date there; the phone
  prints its own. Not a web fix, a locale difference.
- **Next:** review whatever he typed (13b+, 14a) with `review-stack.sh`,
  ask for 13b steps 5 and 6 and the 13b+ phone steps, then write 14b.
- **Scratch:** `docs/ios/.scratch/p13bplus/` (`apply.py`, `build_guide.py`,
  `docs.py`, `guide.template.md`, the `*.before.swift` copies, the head of
  ProfileCard) and `docs/ios/.scratch/p14a/` (`gen.ts`, `build_guide.py`,
  `guide.template.md`, `verify.sh`, `stops.sh`, `kelvin14a.sh`,
  `docchecks.sh`, `decisions.py`, `docs14a.py`, logs). Safe to delete from WSL.

## Current handoff (2026-10-21, 10:40)

This section supersedes the "08:00" handoff below, kept as history.

- **13a typed and committed** (`d74eb54`, "Phase13a"), working tree clean.
  `review-stack.sh phase-13a-…`: all seven files SAME, his tree
  `BUILD_OK`; his Sources are identical to the reference; his own suites
  **544/544** and **128/128** (about 10:05).
- **Kelvin's 13a phone check (2026-10-21, 09:58): everything checks out.**
  Both entry points (Profile; Today's "Import my schedule") with the .ics and
  CSV buttons; the .ics preview counts, Cancel adds nothing, Add files
  classes and deadlines; CSV required and optional columns, "Mon, Wed",
  "MWF", "TR", 12- and 24-hour times; invalid, empty and over-3 MB files,
  missing columns, cancelled, past and duplicate-looking events; the term
  question once, with suggested dates and Not now; persistence after a
  relaunch; a failed save reporting nothing added.
- **A test time bomb, fixed (D-85).** `BackupStoreTests`' web file marked
  History and Reading deleted at 1790000000000 ms (2026-09-21 14:13:20
  UTC); at 14:13 UTC today that turned 30 days old, so the clear-out on open
  (D-75) purged them on `Store.load()` and three restore tests failed, in the
  reference and in Kelvin's copy. The code is right; the test now dates them
  a day before each run (`GONE`, `GONE_MS` interpolated into the raw string).
  Kelvin was told mid-session; the guide has him copy the file first.
- **The 13b guide:** [phase-13b-paste-a-timetable-and-class-form-imports.md](phase-13b-paste-a-timetable-and-class-form-imports.md).
  Two new files (`Logic/PasteSchedule.swift`,
  `Screens/Import/PasteScheduleView.swift`), two replaced
  (`Screens/Import/ImportView.swift`: Paste a timetable and `ImportSheet`'s
  `onImported`; `Screens/Courses/CourseFormView.swift`: the import button,
  the term question, `finish` and `close` moved out of `save`), in two stops.
  Copy three test files (`PasteScheduleTests`, `PasteStoreTests`, the fixed
  `BackupStoreTests`); no script changes.
- **Decisions:** D-83 (the repeat message's curly quotes), D-84 (the paste
  box as its own sheet with a pinned bar, round ticks, no length cap on the
  box; the class form closes after an import; nothing said on the Profile
  card after a paste, as on the web), D-85 (the test fix). PHASES' planned
  concept "a `Result` you return" was already 11a's, so 13b teaches
  `LazyVStack` instead, beside the `Hashable` key and the subscript.
- **Verification:** reference `BUILD_OK`, no warnings. `logic-test.sh`
  **568/568** in the default zone, New York, Kolkata, London and Auckland
  (+24, `PasteScheduleTests`: the web's six cases, 17 parity cases with
  "web:" values from the web's own functions in node 24
  (`.scratch/p13b/paste.ts`, `review.ts`), one for the subscript).
  `persistence-test.sh` **120/120** (+4, `PasteStoreTests`). `doc-check.sh
  phase-13b-…`: IDENTICAL, `BUILD_OK`. His suites in a throwaway copy with
  the guide's blocks and the three test files: **568/568** and **132/132**.
- **Not tried, can't be here:** anything on the phone, above all pasting
  cells copied from a spreadsheet app (guide step 5: do they arrive with
  tabs?), and the import sheet and the class form closing one after the
  other (step 6).
- **Next review:** diff his typed 13b (`review-stack.sh
  phase-13b-paste-a-timetable-and-class-form-imports.md`), run his
  scripts, and ask for section 5, above all steps 5 and 6. Then Phase 14
  (sign-in and sync, with the live feed link moved there by D-79), unless
  Kelvin's gamification rework brings Phase 12 back first.
- **Scratch:** `docs/ios/.scratch/p13b/` holds this session's one-offs
  (`paste.ts`, `review.ts` run with node from that folder against
  `../p13/weblib`; `verify.sh`, `kelvin13b.sh` and their logs; `guide-13b.md`
  the guide's template; `BackupStoreTests.before.swift`). Safe to delete from
  WSL.

## Current handoff (2026-10-21, 08:00)

This section supersedes the "00:25" handoff below, kept as history.

- **11b+c typed and committed** (`65aedf2`, "Phase11bandc"), working tree
  clean. `review-stack.sh phase-11bc-…`: all sixteen files SAME, his tree
  `BUILD_OK`; his Sources are identical to the reference; his suites in a
  throwaway copy **506/506** and **120/120** (his `CourseDeletionTests`
  change is in).
- **Kelvin's 11b+c phone check (2026-10-21, 07:25): everything good.**
  Backup read back as Already Here; Merge and Undo; Replace and Undo;
  Recently Deleted (restore, then the two-step Delete now); a class restored
  with its work and notes; `classping.ics` shared, saved to Files and opened
  into Calendar, weekly within the term with its alarm; Clear all data
  keeping name and theme, Merge bringing the planner back. Steps 6 (a bad
  file) and 10 (a web backup) not mentioned.
- **Phase 12 on hold (D-79):** Kelvin: "we can skip that and jump to phase
  13; there are few changes I'll work on for the gamification." Phase 13
  needs nothing from 12. Told him: the web credits XP on import; the phone
  credits none until Phase 12, like every class and task added so far.
- **Phase 13 split (D-79):** 13a, files (.ics, CSV), the preview, the term
  setup sheet, Today's "Skip the typing", the Profile card; 13b, paste a
  timetable and the class form's import button and term question. The live
  feed and its reconcile preview move to 14 (`/api/import/ics` needs
  sign-in, D-7); screenshot/PDF stays in 15. No class ceiling (D-80); three
  wording changes (D-81); text read exactly as the web reads it (D-82).
- **The 13a guide:** [phase-13a-import-a-calendar-or-schedule-file.md](phase-13a-import-a-calendar-or-schedule-file.md).
  Five new files (`Logic/ICSImport.swift`, `Logic/CSVImport.swift`,
  `Store+Import.swift`, `Screens/Import/TermSetupSheet.swift`,
  `Screens/Import/ImportView.swift`), two replaced (`Screens/ProfileView.swift`: the card; `Screens/Today/TodayView.swift`:
  `.importSchedule` and the first-run card), in three stops. Copy three test
  files; add `Store+Import` to `scripts/test-store.sh`.
- **Verification:** reference `BUILD_OK`, no warnings. `logic-test.sh`
  **544/544** in the default zone, New York, Kolkata, London and Auckland
  (+38: `ICSImportTests` 28, the web's cases but `planImport`'s six, plus
  parity cases; `CSVImportTests` 10). "web:" values from the web's own
  functions in node 24 (`.scratch/p13/weblib/imp.ts`). `persistence-test.sh`
  **116/116** (+8, `ImportStoreTests`; the tool copies `Store+Import`).
  `doc-check.sh phase-13a-…`: IDENTICAL, `BUILD_OK`. His suites in a
  throwaway copy with the guide's blocks, the tests and the script word:
  **544/544** and **128/128**.
- **Sample files for the phone:** `docs/ios/samples/classping-sample.ics`
  and `.csv` (every item ends in "(sample)"). Both give the same classes,
  work, colors, days, times and term in the web's parser (node) and the
  phone's (swiftc on the reference Logic).
- **Not tried, can't be here:** anything on the phone, above all whether the
  Files picker offers a .ics for `[.calendarEvent, UTType(filenameExtension:
  "ics")]` (guide step 2), and the term sheet rising over the import sheet.
- **Next review:** diff his typed 13a (`review-stack.sh
  phase-13a-import-a-calendar-or-schedule-file.md`), run his scripts, and
  ask for section 5, above all step 2 (the picker) and step 3 (where the
  work is filed). Then write **13b**: `lib/paste-schedule.ts` and its test
  file (the `?${name}?` message is web fix 9), `PasteSchedule.tsx` (the
  `initialRows` review half waits for 15), and the class form's import
  button and term question (`ClassForm.tsx` lines 140 to 155, 190 to 200,
  360 to 380).
- **Scratch:** `docs/ios/.scratch/p13/` holds this session's one-off
  scripts (`logic.sh` five zones, `store.sh`, `kelvin13a.sh`,
  `assemble13.py`, `guide-13a.md` the guide's template, `swiftcheck/`, and
  `weblib/` with `imp.ts`, `samples.ts`, `intl.ts`; run node with
  `node.ps1`). Safe to delete from WSL.

## Current handoff (2026-10-21, 00:25)

This section supersedes the "22:45" handoff below, kept as history.

- **Kelvin's 11a phone check:** steps 4 to 9 all work (2026-10-20, 23:04).
  11a is done on the phone. After 11a he committed `875fac8`
  ("timezonefix"): `Calendar.current` became `Calendar.autoupdatingCurrent`
  in 14 files, and `ClassPingApp.swift` rebuilds reminders when the phone's
  time zone or clock changes. **The reference was re-based on it**
  (identical to his tree before 11b+c).
- **D-69 answered:** no web change now; web fixes wait until the app is done
  (D-78). They're collected below under "Web fixes for after the app".
- **11b and 11c in one guide** at Kelvin's request (D-72):
  [phase-11bc-backups-deleted-and-calendar.md](phase-11bc-backups-deleted-and-calendar.md).
  Another session had left an untested 11b+c draft in the reference at
  23:38 (13 files, no tests, no guide, the calendar export missing); Kelvin
  confirmed it had stopped, and this session took it over: fixed the save
  sheet's `onCancellation` overload (it needs a `WritableDocument`), whole
  seconds for every moment read from or written to a file (D-73), the
  web's exact warning words, and the web's `Number(true)` version quirk;
  added `Logic/CalendarExport.swift`, `Screens/Profile/CalendarCard.swift`
  and Course's `CalendarClass` sign-up (D-77); the term setup sheet moved to
  Phase 13 (D-72).
- **The guide:** 11 new files, 5 changed, in three stops (logic; models and
  store; screens). Copy 5 test files, add `Models+Backup Store+Backup
  Store+Trash` to `scripts/test-store.sh`, and change one line in his own
  `Tests/Store/CourseDeletionTests.swift` (line 23, `let old` from 2023 to
  yesterday): the new 30-day clear-out on open (D-75) correctly deletes his
  2023-stamped "earlier delete" fixtures on reload, failing three of his
  tests until then.
- **Verification:** reference `BUILD_OK`, no warnings. `logic-test.sh`
  **506/506** in the default zone, New York, Kolkata, London and Auckland
  (+86: `BackupTests` 39, `RecoveryTests` 10, `CalendarExportTests` 37,
  including two whole .ics files equal line for line to the web's
  `buildCalendarFile` output). `persistence-test.sh` **108/108** (+30:
  `BackupStoreTests` 18 on a real web-made backup file, `TrashStoreTests`
  12; `tools/persistence-test.sh` now copies the three new store files).
  `doc-check.sh phase-11bc-backups-deleted-and-calendar.md`: IDENTICAL,
  `BUILD_OK`. His own suites in a throwaway copy with the guide's code, the
  tests, the script line and the one-line test change: **506/506** and
  **120/120**.
- **Both directions of D-66:** a web file (the web's `buildBackup` in node)
  restores on the phone with every field; a phone backup (the reference
  store code, built in a throwaway package) passes the web's own
  `validateBackup` with no warnings, and the items both have differ only in
  dropped milliseconds (a snooze, a note's last edit), `additionalMeetings:
  []` and `kind: "assignment"` written out. The web's preview calls those
  items "updated" because it compares by key order (web fixes, 4).
- **Not tried, can't be here:** anything on the phone, above all the save
  sheet's file name (`.json` added?), reading a file from iCloud Drive, and
  whether the share sheet offers Calendar for `classping.ics` (guide step 9).
- **Next review:** diff his typed 11b+c (`review-stack.sh
  phase-11bc-backups-deleted-and-calendar.md`), run his scripts, and ask for
  section 5, above all steps 2 to 5 (backup, read back as Already Here,
  Merge, Replace, Undo) and step 9 (the calendar). Then Phase 12 (progress
  and pet), which starts by reading the `game` blobs 11b+c keeps.
- **Scratch:** `docs/ios/.scratch/` holds this session's one-off scripts
  (`snap.sh`, `cal.ts`, `rec.ts`, `bak.ts`, `cross.ts`, `export.sh`,
  `kelvin-suites.sh`, `zones.sh`, `store.sh`, `assemble.py`,
  `guide-template.md`), the web lib copy `weblib/` and the fixtures
  (`web-backup.json`, `phone-backup.json`). Safe to delete from WSL (the
  Cowork shell can't delete). To redo a "web:" value, run node on Windows in
  that folder: `$env:TZ="America/New_York"; node --no-warnings bak.ts` (or
  `cal.ts term out.txt` for the calendar lines). `snap.sh` re-copies his
  tree into `.scratch/kelvin/` for diffing.

## Current handoff (2026-10-20, 22:45)

This section supersedes the "22:00" handoff below, kept as history.

- **11a committed** (`1068a9f`, "phase11a"). His Sources match the reference
  except one deliberate change in `SemesterSection.swift`: `range(for:)` no
  longer clamps one date to the other. Adopted into the reference and the
  11a guide (D-71); `doc-check.sh` on the guide is IDENTICAL again. His three
  new test files are identical; `Store+Profile` is in his `test-store.sh`.
  His suites in a throwaway copy: **420/420** and **90/90**; his tree
  `BUILD_OK`.
- **Phone:** Kelvin, 22:40: the profile and picking a photo work. Steps 4 to
  9 (name, appearance lines, the scale card in Profile, the semester, Start
  a new term up to Cancel) not reported yet.
- **Still open:** D-69, whether to fix the web's "Starts in 1 day" too. The
  web branch `ios-web-fixes` is unmerged, with his own uncommitted web work
  in the working tree.
- **Next:** 11b, backup, restore and clear data in the web's v4 format
  (D-66).

## Current handoff (2026-10-20, 22:00)

This section supersedes the "21:00" handoff below, kept as history.

- **10b committed** (`11e4586`, "phase10b"); his tree was identical to the
  10b reference before 11a. The five web files were committed for him on
  branch `ios-web-fixes` (`7ee0c47`, not pushed, not merged into `main`).
- **Kelvin's answers:** photo picked and kept on the phone (D-65); backups in
  the web's format (D-66, for 11b); the grading scale card moves to Settings
  (D-67). Phase 11 split into 11a, 11b, 11c (D-70).
- **Next for Kelvin:** [Phase 11a](phase-11a-settings-you-and-the-term.md).
  Six new files (`Logic/Avatar.swift`, `Logic/Term.swift`,
  `Store+Profile.swift`, `Screens/Profile/ProfileCard.swift`,
  `GradingSection.swift`, `SemesterSection.swift`), two replaced
  (`ProfileView.swift`, `GradesView.swift`: three spots), three test files
  copied, and `Store+Profile` added to `scripts/test-store.sh`.
- **11a verification:** reference `BUILD_OK`, no warnings; `logic-test.sh`
  **420/420** (default and New York; `AvatarTests` +7, `TermTests` +8, web
  lines printed by node); persistence **78/78** (`ProfileStoreTests` +8,
  `Store+Profile` added to `tools/persistence-test.sh`); `doc-check.sh
  phase-11a-settings-you-and-the-term.md` IDENTICAL, `BUILD_OK`; his suites
  with the new tests and script line, against the new source: **420/420** and
  **90/90**.
- **Found while building:** xtool's build needs `import _PhotosUI_SwiftUI` for
  `PhotosPicker` (D-65); the web's Semester card always says "Starts in 1
  day" (D-69, phone fixed, web left alone pending Kelvin).
- **New decisions:** D-65 to D-70.
- **Next review:** diff his typed 11a, run his scripts, ask for section 5
  (above all the photo surviving a full close). Step 9 stops at Cancel
  unless he chooses to archive: neither app can un-archive a class. Then 11b
  (backup, restore, clear data, `lib/backup.ts` v4).

## Current handoff (2026-10-20, 21:00)

This section supersedes the "late night" handoff below, kept as history.

- **10a committed** (`d57dbdb`, "phase10"). **10b typed, staged, identical to
  the reference** (Sources, `Info.plist`, `xtool.yml` with `infoPath`,
  `AmbientTests`). Kelvin, 20:56: the sound works, follows the timer, and
  shows on the lock screen with working buttons, so locked playback is
  proven on the phone (D-63, D-64). The first-tap pause question wasn't
  answered.
- **Web files still uncommitted** (D-59, D-61: `components/FinalsCountdown.tsx`,
  `lib/report.ts`, `lib/report.test.ts`, `app/api/export/grades/route.ts`,
  `app/grades/page.tsx`). Offered to commit just those five for him.
- **Next:** Phase 11, Settings in the Profile tab. Proposed split: 11a profile,
  appearance and semester; 11b backup, restore and clear data (`lib/backup.ts`);
  11c Recently Deleted (`lib/recovery.ts`) and the calendar export
  (`lib/calendar.ts`). Account, Rate ClassPing and LMS import wait for
  Phases 13 to 15. Asked Kelvin about the photo, the backup format and where
  the grading scale lives.

## Current handoff (2026-10-20, late night)

This section supersedes the "night" handoff below, kept as history.

- **10a typed and passed on the phone** (Kelvin, 19:25: every check works,
  including the alert with the phone locked). Staged, not committed when
  last looked; his staged Sources are identical to the reference. The 10b
  guide opens by asking him to commit. The five web files (D-59, D-61) were
  still uncommitted too; asked again.
- **D-63 spike, done:** a throwaway xtool project with `infoPath: Info.plist`
  in `xtool.yml` got `UIBackgroundModes: [audio]` into the built app, and an
  `AVAudioSession` / `AVAudioPlayer` app built without warnings. A throwaway
  copy of Kelvin's project with the 10b files, `Info.plist` and the
  `xtool.yml` line built too, with the key in the app beside xtool's own.
  Locked playback itself is unproven until his phone (10b step 3).
- **Next for Kelvin:** [Phase 10b: Ambient sound](phase-10b-ambient-sound.md).
  Two project files (`~/ClassPing/Info.plist` new; `infoPath: Info.plist` in
  `xtool.yml`), four Swift files (new: `Logic/Ambient.swift`,
  `Audio/AmbientPlayer.swift`; replaced: `StudySetupView.swift`,
  `StudyTimerView.swift`), and `AmbientTests.swift` copied.
- **10b verification:** reference `BUILD_OK`; `logic-test.sh` **405/405**
  (default and New York; `AmbientTests` +13, including the web's samples for
  mulberry32 seed 1 within 1e-6); persistence **70/70**; `doc-check.sh
  phase-10b-ambient-sound.md` IDENTICAL, `BUILD_OK`; his suites with the new
  test file against the new source **405/405** and **82/82**.
- **New decision:** D-64.
- **Next review:** diff his typed 10b, run his scripts, ask for section 5,
  above all the locked playback and the lock-screen buttons. Then Phase 11
  (Settings inside the Profile tab).

## Current handoff (2026-10-20, night)

This section supersedes the 16:20 handoff below, kept as history.

- **9b+ and the finals fix are committed:** `b08680f` (9b+) and `4108db2`
  (D-60, his message "phase9b"). His `FinalsCountdown.swift` differs from the
  9b+ fix doc only in comments; the reference now uses his file.
- **Disk check settled:** Kelvin set today again after testing Clear; the
  card and planner.json agree. The read-only watcher and `.scratch` were
  removed.
- **Kelvin's answers (2026-10-20):** alerts at block ends (D-62); ambient
  sound tested first and built in 10b (D-63).
- **Next for Kelvin:** [Phase 10a: The study timer](phase-10a-study-timer.md).
  Seven source files (new: `Logic/Study.swift`,
  `Screens/Study/StudySetupView.swift`, `Screens/Study/StudyTimerView.swift`;
  replaced: `Store+Planning.swift` (`addStudySession`),
  `Store+Notifications.swift` (study alerts; the sync keeps them),
  `ClassPingApp.swift` (no route for a study alert tap),
  `Screens/Tasks/AssignmentDetailView.swift` (Start studying)), then
  `StudyTests.swift` and `StudyStoreTests.swift` copied. No script change.
- **10a verification:** reference `BUILD_OK`, no warnings; `logic-test.sh`
  **392/392** (default and New York); `persistence-test.sh` **70/70**. His
  suites plus the two test files against the new source: **392/392**,
  **82/82**. `doc-check.sh phase-10a-study-timer.md` over `4108db2`:
  IDENTICAL, `BUILD_OK`. "web:" values (clock, span, `Math.round`) from the
  web's own functions in node 24.
- **Web, D-61 (uncommitted):** `lib/report.ts` (`generatedOn`, `reportDay`,
  in the CSV and the PDF), `app/api/export/grades/route.ts`,
  `app/grades/page.tsx` (sends `dayOf(new Date())`), `lib/report.test.ts`
  (+3). `npx vitest run --project unit` **1084/1084** with
  `TZ=America/New_York`; eslint on the four files and `npx tsc --noEmit`
  clean. The earlier D-59 change (FinalsCountdown.tsx, the byte-order mark)
  is also still uncommitted unless he has done it.
- **Next review:** diff his typed 10a against the reference, run his scripts
  in throwaway copies, and ask for section 5's checks, above all the pocket
  test (an alert with the phone locked after coming back to the app
  mid-session), Stop cancelling the alert, and blocks recorded once. Then the
  10b background-audio spike.

## Current handoff (2026-10-20, 16:20)

This section supersedes the "late" handoff below, kept as history.

- **D-60 typed, works on the phone (Kelvin, 16:17: "That fixed it"),
  uncommitted.** His `FinalsCountdown.swift` differs from the reference only
  in comments (`diff`: five comment blocks).
- **9b+ checks (Kelvin):** Done shows over the keyboard on every field,
  including a meeting's Room and the credit-hours pad. The accented name in
  Excel wasn't mentioned: unconfirmed.
- **Disk check, unresolved:** the watcher logged writes at 16:13:59, 16:14:00
  and 16:14:57, all with `finalsDate` 2026-10-20, and no write without a
  date; the file still says 2026-10-20. Fine if he set today again after the
  test; if his card shows the "Add your finals date" prompt, screen and disk
  disagree. Asked him which.
- **Web Generated date:** yes, in Phase 10 (D-61).
- **Next:** Phase 10 (study timer). Proposed split: 10a the timer and
  Pomodoro (`lib/study.ts`, `StudyTimer.tsx`, sessions saved, a local
  notification when a block ends) plus D-61 on the web; 10b ambient sound
  (`lib/ambient.ts`, which needs iOS background audio, so a spike first).

## Current handoff (2026-10-20, late)

This section supersedes the evening handoff below, kept as history.

- **9b+ typed and committed** (`b08680f`), identical to the reference.
- **Kelvin's report:** after Clear and a full close the finals card still
  shows a date (first the previous date in 9c, then today in 9b+).
- **Evidence:** the phone's `Documents/planner.json`, read over USB with
  `afcclient --container XTL-V6P7S9UKM7.space.classping.ios` (read-only; xtool
  prefixes free-account bundle ids with `XTL-<team>.`), was last written
  15:57:51 with `finalsDate` 2026-10-20. A read-only watcher logged no write
  between 15:08 and 15:55 (Kelvin tested after it ended). The container also
  holds an old `planner.unreadable.json` (Oct 16, the sample classes only):
  the Phase 1 safety net set an unreadable planner aside once.
- **Diagnosis [Likely]:** Save tapped after Clear. After Clear the card left
  the picker open with a date in it right above Save. Fix written:
  [phase-09b-plus-fix-finals-card.md](phase-09b-plus-fix-finals-card.md)
  (D-60, one file, `FinalsCountdown.swift`). Reference `BUILD_OK`;
  `doc-check.sh` IDENTICAL over `b08680f`, `BUILD_OK`. Asked Kelvin to say if
  he never tapped Save, in which case something else writes the date.
- **Watcher running:** `docs/ios/tools/.scratch/watch.sh` (started ~16:05,
  90 minutes) logs every planner.json write and its finalsDate to
  `docs/ios/tools/.scratch/watch.log`. Read it after his next test, then
  delete `.scratch` (from WSL; the Cowork shell can't delete).
- **Still waiting on:** the other 9b+ checks (Done in a room field, the
  credit-hours pad, an accented name in Excel) and the web Generated-date
  question. Then Phase 10.

## Current handoff (2026-10-20, evening)

This section supersedes the afternoon handoff below, kept as history.

- **9c on the phone (Kelvin, 2026-10-20, 14:19):** the countdown matches the
  calendar, the report is good, light and dark are good. One report: "when I
  clear and close the app it shows the previous set exam/final date".
  [Likely] the picker, which kept the cleared date (the store test proves a
  cleared date persists as nil); if the countdown number itself came back
  after a full close, it's a different bug. Asked him to say which.
- **Next for Kelvin:** [Phase 9b+: Fields everywhere, and two 9c fixes](phase-09b-plus-fields-everywhere.md).
  Seven replaced files: `CourseFormView` (new `CourseField` enum, focus),
  `MeetingFields` (takes `FocusState<CourseField?>.Binding`),
  `AssignmentFormView`, `QuickTaskSheet`, `GradeFormView` (the class sheet in
  a `NavigationStack`), `FinalsCountdown` (D-58) and `TermReportCard` (the
  byte-order mark, D-59). No test changes.
- **9b+ verification:** reference `BUILD_OK`, no warnings; `doc-check.sh
  phase-09b-plus-fields-everywhere.md`: the seven blocks over his `10718e9`
  tree are IDENTICAL to the reference, `BUILD_OK`. No Logic or store file
  changed (371 / 67 stand).
- **Web changes made with Kelvin's yes (D-59), not committed:**
  `components/FinalsCountdown.tsx` (local-day count), `lib/report.ts`
  (`gradeReportBlob` with a byte-order mark, used by `downloadGradeReport`),
  `lib/report.test.ts` (+1 test). With `TZ=America/New_York`: `npx vitest
  run --project unit` **1081/1081**, eslint on the three files clean, `npx
  tsc --noEmit` clean. The web tree has Kelvin's other uncommitted work (the
  desk-display removal and more), so he should commit these three files on
  their own; pushing `main` deploys.
- **Still open on the web:** the CSV's Generated date is the server's UTC
  day (`/api/export/grades` runs in UTC), so fixing it means the browser
  sends its own day in the request. Not covered by his yes; asked.
- **Next review:** diff his typed 9b+ (`diff -r` of his Sources against the
  reference), build a throwaway copy, and ask for section 5's checks: Done in
  a meeting's room field, the number pad's Done, Clear then a full close, and
  an accented name in Excel. Then Phase 10.

## Current handoff (2026-10-20, afternoon)

This section supersedes the morning handoff below, kept as history.

- **Update, 14:05: 9c is typed and committed.** `2f554bc` ("phase9b") and
  `10718e9` ("Phase9c"), each on its own; working tree clean. His Sources are
  IDENTICAL to the reference; his three 9c test files match it apart from
  "Run:" lines. Throwaway copy: `test-logic.sh` **371/371** (also with
  `TZ=America/New_York`), `test-store.sh` **79/79**, `build-check.sh`
  `BUILD_OK`, no warnings. **Waiting on:** the 9c phone checks (guide
  section 5), and Kelvin's call on whether 9b+ (D-55) comes before Phase 10.

- **9b is typed and passed on the phone, not committed.** Kelvin's tree is
  `e79050e` plus 9b uncommitted: all eight 9b source files are identical to
  the reference (`diff -rq` of his Sources against the reference: empty). His
  test files differ from the reference only in old "Run:" lines and his own
  older versions. Throwaway copy: `test-logic.sh` **342/342**,
  `test-store.sh` **75/75**, `build-check.sh` on his Sources `BUILD_OK`, no
  warnings. Kelvin, 2026-10-20: all checks passed on the phone, editing and
  grade projection included. The 9c guide opens by asking him to commit 9b
  on its own first.
- **Next for Kelvin:** [Phase 9c: Finals countdown and the term report](phase-09c-finals-and-report.md).
  Seven source files (four new: `Logic/Finals.swift`,
  `Logic/GradeReport.swift`, `Screens/Grades/FinalsCountdown.swift`,
  `Screens/Grades/TermReportCard.swift`; three replaced: `Store+Grades.swift`,
  `Screens/Grades/GoalCard.swift` (three rounding lines), and
  `Screens/Grades/GradesView.swift`), then three test files copied (4.8). No
  script change. After 9c, Phase 9 is done except the server PDF (D-6).
- **9c verification (2026-10-20):** reference `BUILD_OK`, no warnings;
  `logic-test.sh` **371/371** with the default zone, `TZ=America/New_York`
  and `TZ=Asia/Kolkata` (+22 in the new `GradeReportTests`, +7 in the new
  `FinalsTests`); `persistence-test.sh` **67/67** (+4 in `GradeStoreTests`).
  Kelvin's own suites plus the three test files against the new source:
  **371/371** and **79/79**. `doc-check.sh phase-09c-finals-and-report.md`:
  the seven blocks over his tree are IDENTICAL to the reference, `BUILD_OK`.
- **Web outputs:** the "web:" cases (csvField, `toFixed`, `String(n)`, a whole
  report file, the 3.125 GPA) are `lib/report.ts`'s own output: node 24 on
  Windows, `--experimental-transform-types` (`lib/pdf.ts` has parameter
  properties, so strip-only mode fails), from a scratch copy with `.ts`
  import suffixes. WSL has no node.
- **Found on the web (D-56):** `components/FinalsCountdown.tsx`'s own
  `daysUntil` parses the date as UTC midnight, so west of London the count is
  a day short and finals day says "Done" (node, `TZ=America/New_York`: 50
  instead of 51 from Oct 20 to Dec 10; -1 on Dec 10). `buildGradeReport`'s
  Generated line is the UTC date (2026-12-11 for 21:30 EST on Dec 10). The
  phone counts local days and dates the report locally. Web fixes: open
  question 21.
- **Found on the phone (D-57):** 9a/9b format GPAs and percentages with
  `.formatted(.number.precision(.fractionLength(n)))`, which rounds exact
  halves to even (Swift Foundation in WSL: 3.125 -> "3.12", 6.25 -> "6.2";
  the web says "3.13", "6.3"). 9c switches those eight spots to `jsFixed`,
  the same function the CSV uses.
- **New decisions:** D-56 (local calendar days for finals and Generated),
  D-57 (`toFixed` rounding on the Grades screen).
- **Next review:** diff Kelvin's typed 9c against the reference (`diff -r` of
  his Sources, or `review-stack.sh phase-09c-finals-and-report.md`), run his
  scripts in throwaway copies, and ask for section 5's phone checks, above
  all: the count against a calendar, Today and Done on the right days, Save
  to Files producing `classping-grades.csv` that opens, and the file's GPA
  matching the card. Then write **9b+** (D-55), then Phase 10.
- **Not tested, and can't be here:** anything on the phone for 9c, above all
  the share sheet (whether Files keeps the name `classping-grades.csv`, and
  whether Mail attaches it as a file).
- **Scratch:** this session's one-off scripts lived in
  `docs/ios/tools/.scratch/` and were removed at the end. To redo a "web:"
  check: copy the `lib/` files into a scratch folder, add `.ts` to their
  relative imports, and run node on Windows with
  `--experimental-transform-types` (and `$env:TZ` for time-zone cases).

## Handoff (2026-10-20, morning)

This section superseded the 2026-10-19 handoff below, which is kept as history.

- **9a is typed and passed on the phone.** Kelvin's commit `e79050e` ("phase 9a")
  is identical to the 9a reference (all seven source files; only the older test
  files' "Run:" lines differ). Throwaway copies: his `test-logic.sh` 316/316,
  `test-store.sh` 69/69, `build-check.sh` on his Sources `BUILD_OK`, no
  warnings. Kelvin, 2026-10-20: all ten 9a device checks work.
- **Kelvin's two requests from that check (D-54):** the prefilled 20% weight
  read as a fixed value, so fields he types into should wear the accent; and
  the keyboard hid Save & add another, so it should be possible to put it
  away. Built into 9b as `Design/Theme+Fields.swift` (accent wells measured at
  4.6 : 1 or better; swipe-down plus a Done bar) on the grade sheet and the
  scale editor. The other forms follow in **9b+** (D-55).
- **Next for Kelvin:** [Phase 9b: Custom scales, goals and what-if](phase-09b-scales-goals-and-what-if.md).
  Eight source files (four new: Theme+Fields, ScaleDraft, GoalCard,
  GradeScaleEditor; four replaced: GPA, Store+Grades, GradeFormView,
  GradesView), then three test files copied (4.9). No script change.
- **9b verification (2026-10-20):** reference `BUILD_OK`, no warnings;
  `logic-test.sh` **342/342** (+21 in `GPATests`, +5 in the new
  `ScaleDraftTests`); `persistence-test.sh` **63/63** (+6 in
  `GradeStoreTests`). Kelvin's own suites plus the new test files against the
  new source: **342/342** and **75/75**. `doc-check.sh
  phase-09b-scales-goals-and-what-if.md`: the eight blocks over `e79050e` are
  IDENTICAL to the reference, `BUILD_OK`. The "web:" test cases were produced
  by running `lib/gpa.ts` itself (node 22, type stripping, scratch copy).
- **New decisions:** D-51 (scale card and editor on Grades until Settings),
  D-52 (Start from asks before replacing typed rows), D-53 (scale and goal
  writes only succeed on disk; goal <= 0 stored as nil; brand color for goal
  chips), D-54 (field look and keyboard), D-55 (the 9b+ pass).
- **Next review:** diff Kelvin's typed 9b against the reference
  (`diff -r` of his Sources, or `review-stack.sh
  phase-09b-scales-goals-and-what-if.md`), run his scripts in throwaway
  copies, and ask for the section 5 phone checks, above all: field text
  readable in dark mode with both accents, Done over the number pad, a field
  tap in the scale editor never deleting its row. Then write **9b+** (D-55)
  and **9c**.
- **Not tested, and can't be here:** anything on the phone for 9b.

## Handoff (2026-10-19, Codex continuation)

This section supersedes the morning snapshot below. The morning snapshot is
retained as history, not as instructions to repeat 8c or type 8d again.

- **User direction:** move to Phase 9. Kelvin confirmed in this conversation
  that 8c's selection/keyboard problem and the notification problem were fixed
  on the phone. No further 8c fix is pending.
- **Actual typed tree:** clean at `a66d453` (`Notification fix`), after
  `2f5e384` (`phase8d done`) and `a924af8` (`changes on 8d`). The old claim that
  D-43 is uncommitted and 8d is untyped is stale.
- **Fresh baseline verification:** typed tree `BUILD_OK`, no warnings;
  its own scripts passed **293 logic tests and 58 store tests**. No device
  installation was performed by Codex.
- **Reference baseline:** brought forward to the four changed source files in
  `a66d453` (ClassPingApp, RootView, Store, Store+Notifications). The changed
  PostClassStoreTests and current NoteStoreTests were copied into the reference.
  Notifications wait for an active screen; a fresh post-class tap resets the
  prompt identity. This preserves Kelvin's work under the next phase.
- **Next for Kelvin:** [Phase 9a: Grades and GPA](phase-09a-grades-and-gpa.md).
  Seven source files, then two copied test files and one source-list addition
  in his store test script. Nothing has been written into `~/ClassPing`.
- **Phase 9 split:** 9a grade entry/GPA; 9b custom scales/goals/what-if;
  9c finals/CSV. Only 9a is delivered now. Phase 9 overall is not complete.
- **New reference verification:** `BUILD_OK`, no warnings; **316/316 logic**
  and **57/57 reference store** tests. Kelvin's current store suites plus
  GradeStoreTests passed **69/69** against the reference source in a disposable
  package. The guide's seven source blocks over his current tree were
  **IDENTICAL** to the reference and built without warnings. No 9a phone UI
  checks have happened yet.
- **Next review:** diff Kelvin's typed 9a against its guide and current
  reference, run his tests/build in disposable copies, and review the
  guide's device checklist before writing 9b. Do not assume 9a is typed.
- **NativeX:** see [the analysis](NATIVEX-HANDOFF-2026-10-19.md). The corpus
  distinguishes a delivered 9a reference from a typed phase; no 9a commit
  or user-device verification has been invented.

## Historical snapshot (2026-10-19, fourth session, morning)

| | |
|---|---|
| **Current step** | Step 3: delivering phases |
| **Next for Kelvin** | 1. **Answer two 8c questions:** after selecting a word and tapping **B**, does it stay selected (so a second tap un-bolds it)? Does the keyboard stay up while **Aa** is open? If the selection doesn't stick, put in 8c section 7's one-line fix before 8d. 2. **Commit D-43** (`RootView.swift`, typed, uncommitted) on its own. 3. D-43's other checks: Done brings the bar back, Notes search, Today's quote. 4. **Phase 8d** ([phase-08d-notes-that-connect.md](phase-08d-notes-that-connect.md)): two new files, five replaced (`Store+Notes.swift` and `NoteView.swift` built on your 8c, D-44); copy `QuickTaskTests.swift` and `NoteStoreTests.swift`. 5. The web repo still has D-39's fix uncommitted (`lib/notes.ts`, `lib/notes.test.ts`) |
| **Next for Claude** | Review 8d once typed (`review-stack.sh phase-08d-notes-that-connect.md`, or `diff -r` of his Sources against the reference), and ask how the quick sheet and the task's Linked notes behaved on the phone. Phase 8 is then done: write **Phase 9** (Grades, PHASES row 9), splitting it if it passes 8 files |
| **Kelvin's project** | Last commit `c0a67a5` (8c), on `b62aafe` (8a and 8b, with D-39's link fix). D-43 typed on top, **uncommitted**. His tree builds (`BUILD_OK`); his `test-logic.sh` 285/285, `test-store.sh` 48/48 (2026-10-19). On the phone (Kelvin, 2026-10-19): 8c works, and the tab bar steps aside while typing a note (D-43). Not yet confirmed: whether the selection sticks after a bar button, the Aa menu and the keyboard, D-43's other three checks |

## Files delivered

| File | Status |
|---|---|
| `WEB-TO-IOS-MAP.md` | Step 1. Updated 2026-10-18: `/prompt` is a card over the app (D-34), `?class=` on the form, `justEndedClass` moved to `Logic/PostClass.swift`, `public/sw.js`'s `notificationclick` under Replace (D-33). Updated 2026-10-17 (second session): `lib/reminders.ts` now maps to `Reminders.swift` + `ReminderPlan.swift` (D-28); exam prep and the rest of planning to 7b; the prompt to 7c; quiet hours into `Screens/Profile/RemindersSection.swift`; the permission note (D-30) |
| `PHASES.md` | Step 2. Phase 7 split into 7a, 7b and 7c (D-29). Phase 8 split into 8a, 8b and 8c (D-36), then 8c into 8c and 8d (D-40); 8a to 8c typed, 8d written and verified (2026-10-19) |
| `DECISIONS.md` | D-1 to D-46 settled (D-33 where a tap goes, D-34 the prompt as an overlay, D-35 active classes in the prompt, D-36 the Phase 8 split, D-37 the phone writes notes, D-38 one Highlight from the editor bar, D-39 links escaped once on both apps, D-40 8c split into 8c and 8d, D-41 what the phone's formatting bar does, D-42 Kelvin's 8a/8b hardening in the reference, D-43 the tab bar steps aside for the keyboard, D-44 Kelvin's 8c hardening in the reference, D-45 a task from a note as a sheet, reading or typing, D-46 where note links go and Add → Note) |
| `phase-00` to `phase-06b` | Written, verified and typed |
| `phase-07a-reminders-ring.md` | Written and verified; typed (`2bb4a69`) |
| `phase-07b-task-reminders-and-plans.md` | Written and verified; typed (`e6ceefa`) |
| `phase-07c-taps-and-prompt.md` | Written and verified; typed (`7bbf7a6`), working on the phone |
| `phase-08a-notes-write-and-find.md` | **New** (2026-10-18). Written and verified; typed (`b62aafe`), with Kelvin's hardening (D-42, noted at the top of the doc) |
| `phase-08b-the-reader.md` | **New** (2026-10-18). Written and verified, on top of 8a's doc (`doc-check-stack.sh`); typed (`b62aafe`), with Kelvin's hardening (D-42, noted at the top) |
| `phase-08c-formatting-and-tidy.md` | Written and verified over Kelvin's typed 8a and 8b (`doc-check.sh`); typed (`c0a67a5`), with Kelvin's hardening (D-44, noted at the top of the doc); works on the phone |
| `phase-08d-notes-that-connect.md` | **New** (2026-10-19). Written and verified over Kelvin's typed 8c (`doc-check.sh`: the doc's 7 blocks over his tree are identical to the reference, `BUILD_OK`) |
| `phase-09a-grades-and-gpa.md` | Written and verified (2026-10-19); typed (`e79050e`), identical to the reference; passed on the phone (Kelvin, 2026-10-20) |
| `phase-09b-scales-goals-and-what-if.md` | Written and verified over `e79050e` (`doc-check.sh`: 8 blocks identical to the reference, `BUILD_OK`). Includes D-54 (Kelvin's field and keyboard requests). Typed (identical, uncommitted), passed on the phone (Kelvin, 2026-10-20) |
| `phase-09c-finals-and-report.md` | **New** (2026-10-20, afternoon). Written and verified over Kelvin's typed 9b (`doc-check.sh`: 7 blocks identical to the reference, `BUILD_OK`). Includes D-56 and D-57. Not typed |
| `reference/Sources/ClassPing/` (9c) | Now the end of **9c**: `Logic/Finals.swift`, `Logic/GradeReport.swift`, `Screens/Grades/FinalsCountdown.swift` and `Screens/Grades/TermReportCard.swift` new; `Store+Grades.swift`, `Screens/Grades/GoalCard.swift` and `Screens/Grades/GradesView.swift` replaced |
| `reference/Tests/` (9c) | `Logic/GradeReportTests.swift` new (22), `Logic/FinalsTests.swift` new (7), `Persistence/GradeStoreTests.swift` +4. Logic 371, reference store 67 |
| `reference/Sources/ClassPing/` (9b) | Now the end of **9b**: `Design/Theme+Fields.swift`, `Logic/ScaleDraft.swift`, `Screens/Grades/GoalCard.swift` and `Screens/Grades/GradeScaleEditor.swift` new; `Logic/GPA.swift`, `Store+Grades.swift`, `Screens/Grades/GradeFormView.swift` and `Screens/Grades/GradesView.swift` replaced |
| `reference/Tests/` (9b) | `Logic/GPATests.swift` +21 (the rest of `gpa.test.ts`), `Logic/ScaleDraftTests.swift` new (5), `Persistence/GradeStoreTests.swift` +6. Logic 342, reference store 63 |
| `reference/Sources/ClassPing/` | **Re-based** on Kelvin's typed 7b (2026-10-18): his `AssignmentDetailView.swift` and `PlanningCards.swift` copied in (`diff -r` against his Sources was then empty). Plus Phase 7c: `Logic/PostClass.swift` and `Screens/Prompt/PostClassPrompt.swift` new; `Store.swift`, `ClassPingApp.swift`, `RootView.swift`, `Screens/Tasks/AssignmentFormView.swift` and `Screens/Today/TodayView.swift` changed. Then (2026-10-18, evening) checked against Kelvin's typed 7c: identical. Plus Phase 8a: `Logic/Notes.swift`, `Store+Notes.swift`, `Screens/Notes/NoteView.swift` and `Screens/Notes/CourseNotesView.swift` new; `Store+Assignments.swift` and `Screens/NotesView.swift` replaced. Plus Phase 8b: `Logic/NoteMarkdown.swift`, `Design/Theme+Notes.swift` and `Screens/Notes/NoteReaderView.swift` new; `Screens/Notes/NoteView.swift` replaced. Then (2026-10-18, late evening) Kelvin's typed 8a and 8b copied in (D-42): `Store.swift` (a comment), `Store+Notes.swift`, `Screens/NotesView.swift`, `Screens/Notes/CourseNotesView.swift`, `Screens/Notes/NoteReaderView.swift` and his `NoteMarkdown.swift` with D-39 put back. Plus Phase 8c: `Logic/NoteFormat.swift`, `Logic/NoteTidy.swift`, `Screens/Notes/NoteFormatBar.swift` and `Screens/Notes/NoteTidySheet.swift` new; `Screens/Notes/NoteView.swift` replaced, built on Kelvin's 8b. Then (2026-10-19) Kelvin's typed 8c copied in (D-44): `Logic/NoteTidy.swift`, `Screens/Notes/NoteFormatBar.swift`, `Screens/Notes/NoteTidySheet.swift`, `Screens/Notes/NoteView.swift` and `Store+Notes.swift` (his `RootView.swift` differs only in D-43's comments, so the reference keeps its own). Plus D-43 (`RootView.swift`). Plus Phase 8d: `Logic/QuickTask.swift` and `Screens/Notes/QuickTaskSheet.swift` new; `Store+Notes.swift`, `Screens/Notes/NoteView.swift`, `Screens/Tasks/AssignmentDetailView.swift`, `Components/AddMenu.swift` and `RootView.swift` replaced. Now the end of **8d** |
| `tools/review-stack.sh` | **New** (2026-10-18). For reviewing: lays the given docs over an empty folder and diffs each file they write against Kelvin's tree, then builds a copy of his tree. `wsl -d Ubuntu -- bash -l /mnt/c/Users/kelvi/Desktop/classping/docs/ios/tools/review-stack.sh phase-08a-notes-write-and-find.md phase-08b-the-reader.md` |
| `tools/doc-check-stack.sh` | **New** (2026-10-18). `doc-check.sh` for a phase written before Kelvin has typed the ones before it: lays several docs' code over his tree in order, diffs with the reference, builds. `wsl -d Ubuntu -- bash -l /mnt/c/Users/kelvi/Desktop/classping/docs/ios/tools/doc-check-stack.sh phase-08a-notes-write-and-find.md phase-08b-the-reader.md` |
| `tools/doc-check.sh`, `tools/doc-extract.py` | **New.** The "extract the doc's code, lay it over Kelvin's files, diff with the reference, build" check, saved so every session runs the same one: `wsl -d Ubuntu -- bash -l /mnt/c/Users/kelvi/Desktop/classping/docs/ios/tools/doc-check.sh phase-07a-reminders-ring.md` |
| `reference/Tests/Logic/` | 7a: `RemindersTests.swift` (33) and `ReminderPlanTests.swift` (19). 7b: `ExamPrepTests.swift` (13) and 2 more in `PlanningTests.swift`. 7c: `PostClassTests.swift` (10). 8a: `NotesTests.swift` (21). 8b: `NoteMarkdownTests.swift` (31). D-42: one of Kelvin's in each of `NotesTests` and `NoteMarkdownTests`. 8c: `NoteFormatTests.swift` (27) and `NoteTidyTests.swift` (18). D-44: two of Kelvin's in `NoteTidyTests`. 8d: `QuickTaskTests.swift` (8). 293 in all |
| `reference/Tests/Persistence/` | 7b: `PlanningStoreTests.swift`, now Kelvin's version (7: the 5 delivered, extended, plus 2 of his own); Kelvin's own `ReminderStoreTests.swift` (3) copied in. 7c: Kelvin's own `PostClassStoreTests.swift` (2). 8a: `NoteStoreTests.swift` (7), now Kelvin's version (11: four tests of his and a file-date check, D-42). D-44: four more of Kelvin's in `NoteStoreTests`. 8d: 8 more at the end of `NoteStoreTests` (links, the picker's rules, a link through a deleted note or task and Undo, what a quick task files). 44 in all |
| `tools/persistence-test.sh` | **Changed:** also copies `Assignment+Deadline`, `Assignment+TaskView`, `Models+Reminders`, `Store+Planning` and (8a) `Store+Notes` (skipping any a tree doesn't have yet), and runs the suites one at a time (`--no-parallel`), since they share one planner.json |

## Verified (2026-10-19, fourth session)

- Kelvin's tree (8c committed as `c0a67a5`, D-43 typed and uncommitted): `build-check.sh` on a copy -> `BUILD_OK`, no warnings; his `scripts/test-logic.sh` 285/285 and `scripts/test-store.sh` 48/48. `diff -r` against the reference: his 8c hardening (D-44, below) and his shorter D-43 comments in `RootView.swift`, nothing else. 8a, 8b and D-39's link fix are committed (`b62aafe`).
- His two new `lineDiff` tests checked against the web: `lib/line-diff.ts` run in node 22 (type stripping, from a scratch copy) gives `d:a s:b s:a a:b` for `a b a` against `b a b`, and 3,500 deletions then 3,500 additions for 3,500 lines all reformatted. Same as his Swift.
- Reference with his 8c copied in: `logic-test.sh` 285/285, `persistence-test.sh` 36/36.
- + Phase 8d: `build-check.sh` -> `BUILD_OK`, no warnings; `logic-test.sh` **293/293** (8 new in `QuickTaskTests`); `persistence-test.sh` **44/44** (8 new in `NoteStoreTests`); `doc-check.sh phase-08d-notes-that-connect.md`: the doc's 7 code blocks over Kelvin's tree are identical to the reference, and `BUILD_OK`.
- Not tested, and can't be here: anything on the phone. Above all the toolbar while typing (Back, bell, plus, bin, Done), the quick sheet's keyboard at half height, and the note screens opening from a task on the Tasks tab and on Today (destinations registered on the detail, D-46).

## Review notes on Kelvin's typed 8c (2026-10-19, `c0a67a5`)

Typed in full and building, and it goes further than the doc in five files. Each change is right (D-44, all now in the reference):

- **`saveNoteBody` for tidy.** Apply and Undo tidy only keep the new body once the planner file write worked; otherwise the note goes back to what it was in memory and the sheet stays. The doc's `updateNote` answers true even when the write fails, so a failed Apply looked applied. His `failedTidyApplyOrUndoKeepsTheOriginalAndCanBeRetried` proves it by turning the planner file into a folder.
- **A lighter `lineDiff`.** An unchanged note and a note with no line in common return at once (the second is all deletions then all additions, the web's tie rule anyway); otherwise two rows of lengths and one Bool per cell instead of a full `Int` matrix, about an eighth of the memory at the 20,000-character limit. Same answers as the web, ties included (checked in node, above).
- **The tidy sheet skips the diff when the tidy changed nothing.**
- **The pens' row scrolls sideways** instead of clipping on a narrow phone. (Its `Spacer` does nothing inside a horizontal `ScrollView`; harmless.)
- Tests: two in `NoteTidyTests`, four in `NoteStoreTests` (formatting survives a reload and reads back bold and highlighted; tidy keeps the title, class and link; the failed-write test; tidy can't touch a deleted or over-limit note).
- D-43 typed: same code as the reference, shorter comments, and the header doesn't mention D-43 yet. Fine.

## Verified (2026-10-18, third session, late evening)

- Kelvin's tree (8a and 8b typed, uncommitted): `build-check.sh` on a copy -> `BUILD_OK`. `review-stack.sh` against the 8a and 8b docs: `Logic/Notes.swift`, `Store+Assignments.swift` and `Design/Theme+Notes.swift` identical; the rest differ by his hardening (D-42) and his missing D-39 link fix.
- Reference with his files copied in, plus Phase 8c: `build-check.sh` -> `BUILD_OK`, no warnings; `logic-test.sh` **283/283** (45 new in `NoteFormatTests` and `NoteTidyTests`, 2 of his); `persistence-test.sh` **32/32** (4 of his); `doc-check.sh phase-08c-formatting-and-tidy.md` over his tree: the only difference from the reference is his `NoteMarkdown.swift` without D-39 (expected), and `BUILD_OK`.
- The tidy and diff cases marked "web:" in `NoteTidyTests` are `lib/tidy-note.ts` and `lib/line-diff.ts`'s own output (node 22, type stripping, run from a scratch copy outside the repo).
- Not tested, and can't be here: the bar on a phone, above all whether `TextEditor`'s selection sticks when the text and the selection are set together (section 7 of the 8c doc has the fallback), and whether opening the Aa menu keeps the keyboard up.

## Review notes on Kelvin's typed 8a and 8b (2026-10-18, uncommitted)

Typed in full and building. Three files match the docs exactly (`Logic/Notes.swift`, `Store+Assignments.swift`, `Design/Theme+Notes.swift`). The rest go further, and each change is right (D-42, all now in the reference):

- **Done saves first, and won't lose a draft.** The 8b doc's Done flipped to the reader and left the save to the editor's `onDisappear`; past the 20,000 limit that saved only the title, and the typing was gone with the editor. His Done is in the editor: it saves, and stays put while the body doesn't fit or the write failed. A real data-loss bug in the doc.
- **The bin saves before it deletes,** so Undo brings back the last half second of typing. Another real one.
- **"Saved" is true:** it now also needs the file write to have worked, with a Retry beside the failure line, and `updateNote` writes again when the same draft is retried after a failure (otherwise Retry would do nothing). His `retryingTheSameDraftAfterAFailedWritePersistsIt` proves it.
- **The save-failure line** on the Notes tab, a class's notes and the reader, as the other screens have had since Phase 1.
- **VoiceOver:** headings marked as headings, checkboxes read as Checked or Unchecked, the title and body fields named. And the title and table cells can be selected and copied.
- **`inlineToHtml` can't crash on pasted marker characters:** `stash[Int(g[1]) ?? 0]` indexed past the end for a note holding U+0000, digits, U+0001. His restore leaves such text as it is. His test pins it.
- Still to do in his tree: D-39's link fix in `NoteMarkdown.swift` (he typed 8b before it), and copying the new `NoteMarkdownTests.swift`.
- His tests' "Run:" lines name his scripts (`scripts/test-logic.sh`); the reference's say `tools/…`. Copying a test file over his changes that line, nothing else.

## Verified (2026-10-18, third session, evening)

- D-39 on the web: `npx vitest run --project unit` 1080/1080 (73 in `lib/notes.test.ts`, one new). The journey tests fail on this machine with `TypeError: React.act is not a function` in all 12 files, unrelated to notes (a React / testing-library mismatch in the local install); not investigated.

- Kelvin's typed 7c (uncommitted): Sources identical to the reference; `PostClassTests.swift` identical.
- + Phase 8b: `build-check.sh` -> `BUILD_OK`, no warnings; `logic-test.sh` **236/236** (after D-39); `persistence-test.sh` 28/28; `doc-check-stack.sh` with the 7c, 8a and 8b docs over Kelvin's tree: identical to the reference and `BUILD_OK`. The `inlineToHtml` cases marked "web:" in `NoteMarkdownTests` are `lib/notes.ts`'s own output (node).
- + Phase 8a: `build-check.sh` -> `BUILD_OK`, no warnings; `logic-test.sh` **205/205**; `persistence-test.sh` **28/28**; `doc-check.sh phase-08a-notes-write-and-find.md`: the doc's 6 code blocks over Kelvin's tree are identical to the reference and `BUILD_OK`.
- The 8a `stripMarkers`, `noteTitle`, `notePreview` and `dayLabel` expectations not in `notes.test.ts` were produced by running `lib/notes.ts` itself with node 24 on Windows (type stripping, no build), so they pin the web's real output.
- Not tested: the screens on a phone (focus on appear, the keyboard bar, `.searchable`, `navigationDestination(item:)`).

## Verified (2026-10-18, third session)

- + Phase 7c: `build-check.sh` -> `BUILD_OK`, no warnings; `logic-test.sh` **184/184**; `persistence-test.sh` **19/19** (`Store.swift` now needs `AppRoute`, which the Logic copy brings); `doc-check.sh phase-07c-taps-and-prompt.md`: the doc's 7 code blocks over Kelvin's tree are identical to the reference and `BUILD_OK`.
- `build-check.sh` sanity: a deliberate type error in a copy of the 7c reference gave `BUILD_FAILED` with the error line, so `BUILD_OK` means the iOS SDK compile really passed (Swift 6 concurrency checks included).
- Not tested, and can't be here: the taps themselves, above all a tap that launches a closed app (`initial: true`), and whether `didReceive` gets called (an optional delegate method fails silently if misspelled).
- Kelvin's typed 7b (`e6ceefa`): `build-check.sh` on his Sources -> `BUILD_OK`, no warnings; his `test-logic.sh` 174/174, `test-store.sh` 31/31.
- Reference after re-basing: `persistence-test.sh` 19/19; Sources identical to his.
- Not tested: anything on the phone, for 7a or 7b.

## Verified (2026-10-17, second session)

- Kelvin's Sources at `8e6ff4f`: `build-check.sh` -> `BUILD_OK`, no warnings. His own `scripts/test-logic.sh` 107/107 and `scripts/test-store.sh` 21/21.
- Kelvin's typed 7a (committed as `2bb4a69`): `BUILD_OK`, no warnings; his `test-logic.sh` 159/159, `test-store.sh` 24/24.
- + Phase 7b: `BUILD_OK`, no warnings; `logic-test.sh` **174/174**; `persistence-test.sh` **17/17**; `doc-check.sh phase-07b-task-reminders-and-plans.md`: the doc's 7 code blocks over Kelvin's tree are identical to the reference and `BUILD_OK`.
- + Phase 7a (earlier): `BUILD_OK`, no warnings; `logic-test.sh` **159/159** (also 159/159 with `TZ=Asia/Kolkata` and `TZ=America/Los_Angeles`); `persistence-test.sh` 9/9.
- The eight code blocks in the 7a doc were extracted from the markdown, laid over Kelvin's `8e6ff4f` files and rebuilt: identical to the reference, `BUILD_OK`.
- Not tested: anything on the phone, which for this phase is most of it (permission prompt, notifications arriving closed and open, weekly triggers). Kelvin's `xtool dev` run is that check.

## Review notes on Kelvin's typed 7c (2026-10-18)

Sources identical to the doc. His own `PostClassStoreTests.swift` (2 tests, now in the reference): a route is never saved and survives a save, and deleted notification targets come back missing. One weakness: in the second test the archived class neither ends just before 11:10 nor starts after it, so the test would pass even if archived classes were counted. Making it end at 11:05 would make it prove D-35.

## Review notes on Kelvin's typed 7b (2026-10-18)

Matches the doc, plus three changes, all sound, now in the reference:

- **The detail's Reminder row redraws every minute** (`TimelineView(.everyMinute)` around `detailRow`, and `reminderSummary` takes `now`), so "Snoozed" turns back into the nudge summary when a snooze runs out, in step with the card, which already did this.
- **The exam prep card redraws every minute** the same way (`body` wraps a new `content(_ now:)`), so days left, the ladder and "Study on" move on if the screen stays open past midnight. The doc read `Date.now` once per redraw, which only refreshed when something else changed.
- **`PlanWorkCard` follows the plan** with `.onChange(of: plan?.date)`: "Study on" in the exam card changes the plan, and `@State`'s initial value only runs once, so the picker used to keep showing the old day. A real bug in the doc, caught by him.
- His `PlanningStoreTests.swift` adds an "empty selection still means the defaults after reload" check, a second logged session, and two tests of his own: reminder actions change the persisted notification plan (snooze pushes every reminder past the snooze end, wake and the switch restore it exactly), and complete then reopen keeps the exam steps, the plan and the snooze, with `addPrepSteps` not duplicating.
- Commit message says "phase 7v", a typo for 7b. Harmless.

## Review notes on Kelvin's typed 7a (2026-10-17)

Matches the doc, plus three changes to `Store+Notifications.swift`, all sound, now in the reference:

- **One writer at a time.** `syncReminders` now runs passes of a new `replaceReminders` in a `while` loop guarded by two `static` flags, so two syncs can't interleave their remove and add calls across an `await`. A call that arrives mid-sync asks for another pass instead of racing. (The 7a doc said a second sync was harmless; this is stricter, and right.)
- **Re-plan after the permission box.** If the data, day or minute changed while iOS was asking, the pass asks for another one instead of handing iOS a stale plan.
- **A rejected `add` stays eligible.** Its one-off is taken back out of the "scheduled" record, so the next sync doesn't count it as rung.
- His own `Tests/Store/ReminderStoreTests.swift` (3 tests: deleting a class empties its plan and Undo restores it; completing or switching off a task empties its warnings; quiet hours and the after-class switch survive a reload). `scripts/test-store.sh` now copies `Models+Reminders`.
- `ReminderPlan.swift`: one comment reworded ("it's a class alarm. Other kinds wait for them to end."). Clearer.

## Review notes on Kelvin's typed 4b, 6a and 6b (2026-10-17)

All three match their docs in behaviour. His differences, all improvements, now mirrored in the reference:

- `ClassCard` / `TodayView`: other days pass `nowMin = -1` (not 0), and the card checks `nowMin >= 0`, so a class at midnight still counts as "Now" today. The web uses the same `-1`.
- `TodayView`: the class cards get `.id(dayOf(day))`, so they start expanded again on each newly picked day; a save-failure line at the top.
- `QuoteBanner`: a save-failure line, and Save keeps the editor open when the write failed; the keyboard closes on Save and Cancel.
- `AssignmentDetailView`: a save-failure line at the top.
- `TodaySections`: the summary says "three numbers" (true: the third shows overdue or days clear), and the Edit / Delete buttons name the class for VoiceOver.
- `Records.swift`: the two `Note` field names are fixed, without the `CHANGED` comments.

## The tab bar and the keyboard (2026-10-19, D-43)

Kelvin's screenshot of the note editor: with the keyboard up, the tab bar rode up on it and covered the formatting bar and the "Saved" line (only the edge of the first button showed). A tab's screen stops at the keyboard, not at the bar, so the bar overlaps its bottom whenever the keyboard is up. Probably not notes-only (not yet seen on the phone): Notes search, Today's quote and a task's detail field sit inside a tab too. Fix in `RootView.swift` only: the bar leaves while the keyboard is up. To check on the phone: open a note (bar gone, formatting bar sitting on the keyboard), tap Done (bar back), search on the Notes tab, edit Today's quote.

## Kelvin's typing tracker

| Phase | Typed | Builds | Checked on phone |
|---|---|---|---|
| 0 | yes (2026-10-14) | assumed | not confirmed here |
| 1 | yes (2026-10-14) | assumed | not confirmed here |
| 2 | yes (2026-10-14) | BUILD_OK | yes (2026-10-14) |
| 3 | yes (`7d01f4a`) | BUILD_OK | Kelvin says done |
| 4a | yes (`8755157`, `b0d7dab`, `2d2dc5f`) | BUILD_OK | not confirmed here |
| 4b | yes (`c934e06`) | BUILD_OK (2026-10-17) | Kelvin says done |
| 5a | yes (`3fd880f`) | BUILD_OK | not confirmed here |
| 5b | yes (`3fd880f`) | BUILD_OK | not confirmed here |
| 6a | yes (`8e6ff4f`) | BUILD_OK (2026-10-17) | Kelvin says done |
| 6b | yes (`8e6ff4f`) | BUILD_OK (2026-10-17) | Kelvin says done |
| 7a | yes (`2bb4a69`) | BUILD_OK (2026-10-17) | class alarm and daily nudge: yes (Kelvin, 2026-10-18); "just ended": not confirmed |
| 7b | yes (`e6ceefa`) | BUILD_OK (2026-10-18) | not confirmed here |
| 7c | yes (`7bbf7a6`) | identical to the reference | Kelvin: functional |
| 8a | yes (`b62aafe`), with his hardening | BUILD_OK (2026-10-19) | with 8c (Kelvin, 2026-10-19) |
| 8b | yes (`b62aafe`), with his hardening and D-39 | BUILD_OK (2026-10-19) | with 8c (Kelvin, 2026-10-19) |
| 8c | yes (`c0a67a5`), with his hardening (D-44) | BUILD_OK (2026-10-19) | works (Kelvin, 2026-10-19); the selection after a button and the Aa menu not confirmed |
| D-43 | yes, uncommitted (2026-10-19) | BUILD_OK (2026-10-19) | the bar steps aside while typing a note (Kelvin, 2026-10-19); Done, Notes search and Today's quote not confirmed |
| 8d | yes (`2f5e384`, `a924af8`, then `a66d453` notification fix) | BUILD_OK (2026-10-19) | notifications fixed (Kelvin, 2026-10-19) |
| 9a | yes (`e79050e`), identical to the reference | BUILD_OK (2026-10-20) | all ten checks (Kelvin, 2026-10-20) |
| 9b | yes (`2f554bc`), identical to the reference | BUILD_OK (2026-10-20) | all checks, editing and projection (Kelvin, 2026-10-20) |
| 9c | yes (`10718e9`), identical to the reference | BUILD_OK (2026-10-20) | count, report, light and dark good (Kelvin, 2026-10-20); Clear looked stuck (D-58, fixed in 9b+) |
| 9b+ | yes (`b08680f`, then D-60 as `4108db2`), identical to the reference (his D-60 comments adopted) | BUILD_OK (2026-10-20) | Done on every field (Kelvin, 2026-10-20); D-60: Clear stays cleared (Kelvin, 2026-10-20); Excel accent not confirmed |
| 10a | yes (staged 2026-10-20), identical to the reference | BUILD_OK (2026-10-20) | every check (Kelvin, 2026-10-20) |
| 10b | yes (staged 2026-10-20), identical to the reference | BUILD_OK (2026-10-20) | sound, Pause/Resume, locked playback and lock-screen buttons (Kelvin, 2026-10-20) |
| 11a | yes (`1068a9f`, his D-71 adopted), then his `875fac8` (timezonefix) | BUILD_OK (2026-10-20) | photo and profile (22:40), steps 4 to 9 (23:04), Kelvin, 2026-10-20 |
| 11b+c | yes (`65aedf2`), identical to the reference | BUILD_OK (2026-10-21) | everything good (Kelvin, 2026-10-21); a bad file and a web backup not mentioned |
| 13a | yes (`d74eb54`), identical to the reference | BUILD_OK (2026-10-21) | everything checks out (Kelvin, 2026-10-21, 09:58) |
| 13b | yes (`ba8b0a9`), identical to the reference | BUILD_OK (2026-10-21) | not yet reported (steps 5 and 6 matter most) |
| 13b+ | yes (`5daaae6`, with 14a), same as the guide (blank lines aside) | BUILD_OK (2026-10-22) | not yet (batched after 14cd, D-95) |
| 14a | yes (`5daaae6`, with 13b+), same as the guide (blank lines aside); the last phase Kelvin typed (D-93) | BUILD_OK (2026-10-22) | nothing to see on the phone |
| 14b | pushed by Claude to `ios/phase-14b-row-mapping` (D-98); not merged | BUILD_OK (laptop, 2026-10-22) | nothing to see on the phone |
| 14cd | pushed by Claude to `ios/phase-14cd-sign-in-and-sync` (`fcd664f`); not merged | CI green, xtool OK (2026-10-22) | not yet (section 5 of its note) |

## Web fixes for after the app

Kelvin's call (D-78): the web changes when the app is done. Until then the
phone keeps the web's behavior unless a decision says otherwise. Found so far:

- **Custom profile banner (new feature, D-87):** a profile field, an upload
  route, a deletion sweep with delete account, and a privacy line. The phone
  already shows a blurred-photo banner (D-86); the web has none.

1. **"Starts in 1 day"** on the Semester card for any term not yet begun
   (D-69; the phone counts the real days).
2. **"1 item in this file have no identifier"** in `validateBackup`
   (lib/backup.ts). The phone copies it (D-76).
3. **The restore preview compares with live items only.** `RestoreSheet`
   passes the context's live lists to `planRestore`, but `applyRestore`
   uses everything, deleted items included, so a deleted item previews as
   "new" (the phone compares everything, D-73).
4. **The restore preview compares items by `JSON.stringify`,** so field
   order decides: an identical item from a phone backup (sorted keys) shows
   as "updated". A sorted-key comparison fixes it.
5. **`purgeItems` for a class** leaves its tasks' day plans and the links
   from study sessions and notes (its `emptyTrash` cleans them; the phone
   does both, D-75).
6. **The calendar's `fold`** cuts at 74 UTF-16 units even inside an emoji,
   which breaks it (an exam's 📝 title, or any emoji in a long name).
7. **The term setup sheet can crash.** `dateLabel` in
   `components/TermSetupSheet.tsx` formats the state's dates in "We found a
   term from … to …"; clear one of the two date inputs and it formats an
   invalid date, which throws (node: `RangeError: Invalid time value`), so
   the render fails. The phone can't clear a picker and falls back to the
   other sentence (13a).
8. **"find them on your timetable and Assignments"** after an import
   (`ImportCalendar.tsx`): the tab is Tasks. The phone says "in Tasks"
   (D-81).
9. **"?Biology? repeats a meeting…"** in `buildPastedClasses`
   (`lib/paste-schedule.ts`): plain question marks where the next message
   has curly quotes, lost to an encoding at some point. The phone has the
   quotes (D-83).
10. **The paste box cuts a long paste short.** `PasteSchedule.tsx`'s
    textarea has `maxLength={100000}`, so a longer paste silently loses its
    end and `readPastedSchedule`'s "Paste up to 100,000 characters at a
    time." can never show. The phone's box has no cap (D-84). Dropping the
    attribute fixes it.
11. **Nothing is said after a paste on Settings.** The panel's paste
    `onDone` doesn't set `done`, so the card flips back to its buttons with
    no "Added" line (a file import gets one). The phone matches the web for
    now (D-84); a line would need words for "classes" rather than "items".

Older open questions below that are web changes (1, 3, 5, 6, 10, 13, 18 and
20) still need Kelvin's call on what the fix should be, but not on when: when
the app is done.

## Open questions

1. **"In 1 weeks".** The web's `dueLabel` says "In 1 weeks" for 8 to 10 days out; the Swift port copies it so both apps agree (D-18). Fix both (a one-line web change, needs Kelvin's go-ahead), or leave both?
2. **Priorities (D-23).** Dropped because the web dropped them. If Kelvin wants a "top three today" on the phone anyway, that's a new feature for both apps.
3. **The web's tab bar** still shows Planner (D-19). Does the web change too?
4. **Class alarms ring outside the term.** Neither app checks the term dates before a class alarm or after-class nudge (the web's loop doesn't either, and 7a copies it). After the semester ends, a class keeps ringing until it's archived or deleted. Stop both apps ringing outside the term?
5. **"Due in 24 hours" on the due day.** The web titles every nudge before the deadline "Due in 24 hours", so the 8 AM nudge on the due day says it too, even 2 hours out. Copied for now, like D-18.
6. **Undated exams on the web (D-32).** The web's Exam prep card says "It's today. Good luck." for an exam with no date. The phone hides the card instead. Fix the web the same way (one condition in `app/tasks/[id]/page.tsx`)?
7. **"Warn me early" can't switch off every warning on an exam.** Removing the last one leaves an empty list, which means "not chosen", so the exam's default three come back. The web does the same; the phone copies it. A real "none" needs a stored marker on both apps.
8. **The iOS designs file is still unread** (`Downloads\...\ClassPing Screens.dc.html`). Not blocking.
9. The persistence test still creates an empty `~/Documents` in WSL. Harmless.
10. **Archived classes in the web's prompt (D-35).** `app/prompt/page.tsx` reads every live class, so after a term is archived it can name an old class. Switch it to `activeClasses` (one word), as the phone does?
11. **Yes / No buttons on the after-class notification (D-33).** Left out for now; the body tap asks the question. Add them later (notification categories), for long-press on the phone?
12. **Notes on the phone (D-37).** The web's phone view only reads and highlights; the iOS app also types (plain markdown, reader first from 8b). Kelvin can still ask for read-only, but the Notes tab would stay empty until sync.
13. **"Delete this note? It can't be undone."** The web's list says this, but its store offers Undo for a note (and the phone does too). The phone drops the second sentence. Fix the web's words?
14. **Settled (D-38): one Highlight and Clear.** Was: the web reader's four highlight colours aren't kept. `==text==` stores no colour and every saved highlight draws yellow, so the swatch choice is lost on the next render. 8c will offer one Highlight (and Clear) unless Kelvin wants colours stored, which would be a new marker on both apps.
15. **Settled (D-39): fixed on both apps.** Was: link addresses with `&` break on the web. `inlineToHtml` escapes an already-escaped address again (`&amp;amp;`), so `[x](https://a.b/?p=1&q=2)` opens `…&amp;q=2`. The phone copies the web's HTML, so it breaks the same way. A one-call fix on both (`escapeHtml(href)` → `href`) needs Kelvin's go-ahead.
16. **Settled (D-38): from the editor's bar.** Was: highlighting from the reader. The web's phone highlights by selecting text in the reader. SwiftUI's `Text` lets you select and copy, but iOS 18 doesn't tell the app what was selected, so the phone highlights from 8c's formatting bar instead (select in the editor, tap Highlight). A UIKit text view could do it from the reader, as Phase 16 polish.
17. **Tables, columns and links on the phone's bar (D-41).** Left off: tables and columns are typed (`| a | b |` and a `| --- | --- |` line, or `:::columns`), links as `[words](https://…)`. Templates for them on the bar would be small (Phase 16 polish), if typing them turns out to be a pain.
18. **"Quick note assignment".** A blank quick assignment is named "<class> <kind>" on the web, so from a note with no class it's "Quick note assignment" (filed in the Inbox). The phone copies it (D-45), like D-18. Fix both (say, plain "Assignment" for a note with no class), or leave both?
19. **The Notes tab doesn't open on the class in session.** The web's `/classes` opens straight on the class that's on (`activeId = classId ?? liveClassId`, its auto-scope), so its Add → Note lands there mid-lecture. 8a's Notes tab shows a Now tag instead, and 8d's Add → Note opens the tab as it was left (D-46). Port the auto-scope (a `NavigationPath` for the Notes tab, with Quick note and New note moved onto it), or leave it?
20. **A note linked to a deleted task.** Deleting a task keeps its notes' links, so Undo brings them back (both apps). Until the task is gone for good (Phase 12's Recently Deleted clears the links, as the web's purge does), such a note shows on no task and isn't offered to link elsewhere. Same on the web. Treat a link to a deleted task as no link in the picker, on both?
21. **Settled for the countdown (D-59): fixed on the web 2026-10-20, uncommitted. Still open: the CSV's Generated date (server UTC).** Was: the web's finals countdown is a day short west of London (D-56). `components/FinalsCountdown.tsx` has its own `daysUntil` with `new Date(iso)` (a UTC parse). In Maine, Oct 20 to Dec 10 shows 50 days, and finals day shows "Done" (node, `TZ=America/New_York`). One-line fix: use `daysUntil({ date: finals, time: null }, new Date())` from `lib/deadline.ts`. Also `buildGradeReport`'s Generated line uses `toISOString()` (UTC): after 8 PM EDT it's dated tomorrow; a local-day helper would fix it (its test's `AT` would then need to be a local time). Both need Kelvin's go-ahead.
22. **Settled (D-59): both apps add the mark** (web: `gradeReportBlob`; phone: 9b+). Was: no byte-order mark in the CSV. Both apps write plain UTF-8, which Numbers and Google Sheets read fine; Excel on Windows can garble accented letters in a CSV without a BOM. Add `\uFEFF` at the start on both apps, or leave both?

## Next session

Read the **Current handoff** above and
`phase-13b-paste-a-timetable-and-class-form-imports.md`, then inspect the
live Swift Git status and log (`wsl -d Ubuntu -- bash -lc "cd ~/ClassPing &&
git status --short && git log --oneline | head"`). If 13b is typed, review it
with `tools/review-stack.sh phase-13b-paste-a-timetable-and-class-form-imports.md`,
run his scripts in a throwaway copy, and ask for section 5's phone steps.
Otherwise help him through the guide stop by stop. After that, Phase 14
(sign-in and sync, with the live feed link, D-79). Phase 12 waits for
Kelvin's gamification changes (D-79).
