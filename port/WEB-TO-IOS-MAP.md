# ClassPing web app to iOS: the map

*Step 1 deliverable from [IOS_APP.md](../../IOS_APP.md). Written 2026-10-13 from the web app's source in this folder, and updated the same day with Kelvin's decisions and his actual Swift files.*

**What this is:** every part of the web app, sorted into Port, Rebuild, Connect, Replace or Skip, with the Swift file it becomes. Step 2 (`PHASES.md`) is planned from this file, so nothing gets built that isn't in here.

**How it was checked:** every file in `lib/`, `app/` and `components/` was listed from disk and appears exactly once below. Field lists come straight from `lib/supabase/columns.ts` and `lib/supabase/map.ts`, not from the docs.

**What this session could not see:**

- **The iOS designs file** (`Downloads\...\ClassPing Screens.dc.html`). Only the classping folder is connected, so the screen notes below come from the web pages, not the designs. Connect the Downloads folder (or copy the file into `docs/ios/`) before Phase 3.
- ~~Kelvin's Swift files in WSL~~: read later the same session through Windows. Phase 1 closes the gaps in section 3.

---

## 0. Where the source disagrees with IOS_APP.md

Rule 3.1 says the code wins. These are the places it does:

| IOS_APP.md says | The code says | What the map does |
|---|---|---|
| Five accent colors | `lib/accents.ts` has two: `babypink` (default, `#E85D8A`) and `ocean` (`#3B82C4`). `globals.css` only defines `data-accent="ocean"`. | `Accent` enum with two cases. |
| `app/api/notes/tidy` is a Connect | `components/NoteTidyButton.tsx` now runs `lib/tidy-note.ts` on the device. Nothing in the client calls `/api/notes/tidy` any more. | Note tidy is a **Port**. The route is Skip. |
| `app/lock` is a Rebuild | `app/lock/page.tsx` is a static mock-up of what notifications look like on a lock screen. | **Replace**: on iOS the real lock screen shows the real notifications. |
| `app/api/export/**` is a Connect | `lib/calendar.ts` (ICS export) and the CSV half of `lib/report.ts` are pure functions. | **Port** both and share the file with `ShareLink`. Only the PDF grade report stays a Connect (decision D-6 below). |
| Storage keys `classping.v2:<userId>` | `lib/store.tsx` builds keys from `KEY_PREFIX = "classping.v1"`. | Doesn't matter on iOS (JSON files), noted so nobody ports the wrong string. |

---

## 1. Architecture

```
 WEB APP TODAY                                   iOS APP
 ─────────────                                   ───────
 Clerk (identity, JWT "sub" = user_id)    ───▶   Clerk iOS SDK (Phase 14). Signed out = local only.
 Next.js pages + React context            ───▶   SwiftUI views + one @MainActor @Observable Store
   lib/store.tsx (state, cache, sync,              Store.swift + Store+*.swift extensions
   reminders)
 localStorage                             ───▶   JSON files in Documents/
   classping.v1:<id>        (planner)              planner.json
   classping.v1.snap:<id>   (sync snapshot)        snapshot.json   (Phase 14)
   classping.notified:<id>  (fired today)          not needed: iOS fires scheduled notifications itself
 Supabase (planner rows, RLS, Realtime)   ───▶   supabase-swift with the Clerk token (Phase 14)
 Neon (push subs, email prefs, ledgers)   ───▶   never touched directly. Email prefs via /api/email/prefs
 Next.js API routes                       ───▶   Called with URLSession + "Authorization: Bearer <Clerk JWT>"
 Service worker (cache + notifications)   ───▶   The app binary is the cache. UNUserNotificationCenter
 30s in-app reminder loop                 ───▶   Scheduled local notifications, topped up on launch
 Web push + cron routes                   ───▶   Skip. Needs a paid Apple account (APNs)
 Email crons (Resend)                     ───▶   Unchanged on the server. The phone only edits the prefs
 Tauri desktop shell                      ───▶   Skip
```

**Why the server API is reachable from the app [Likely]:** `lib/request-security.ts` rejects mutations that have no browser `Origin`, *unless* they carry `Authorization: Bearer ...` ("Allow explicit bearer API clients"). `URLSession` sends no `Origin`, so a Bearer Clerk session token should pass. Whether Clerk's `auth()` in each route accepts that token has not been tested. That's the Phase 14 spike.

---

## 2. Navigation

The phone web app (`components/TabBar.tsx`): **Today · Notes · [+] · Planner · Tasks**. The `+` opens `components/AddMenu.tsx`: Assignment, Exam, Reminder, Note, Class. Grades and Settings are reached from Today.

**On iOS since D-19 (2026-10-17):** **Today · Notes · [+] · Tasks · Profile**. The week lives inside Today (a strip that opens into the grid), and Grades and Settings live in the Profile tab. The web app's bar is unchanged for now.

| Web route | iOS screen | How you reach it |
|---|---|---|
| `/home` | `TodayView` | Tab 1 |
| `/classes` | `NotesView` (classes, quick notes, search) → `CourseNotesView` → `NoteView` (8a); the reader in 8b | Tab 2 ("Notes") |
| `/week` | `WeekStrip` + `WeekGrid` inside `TodayView` (D-19) | Today: the calendar button, or pull the strip down |
| `/tasks` | `AssignmentsView` (filters, quick add, level) | Tab 3 |
| `+` button | `AddMenu` sheet | Center of the tab bar, every screen |
| `/tasks/new`, `?kind=exam`, `?kind=reminder`, `?class=` | `AssignmentFormView(kind:)` sheet; `AssignmentFormView(courseID:)` for `?class=` (7c) | Add menu, Tasks; the prompt's Yes |
| `/tasks/[id]` | `AssignmentDetailView` (checklist 4b; exam prep, reminders and Plan the work 7b; linked notes and Open {class} 8d, D-46; study timer later) | Tap a task anywhere |
| `/tasks/[id]/edit` | `AssignmentFormView(editing:)` | Detail, Edit |
| `/class/new` | `CourseFormView` | Add menu → Class (5b), Notes |
| `/class/[id]/edit` | `CourseFormView(editing:)` | The class details sheet from the week grid (5b), a "Not yet scheduled" chip, Notes |
| `/grades` | `GradesView` | Profile, Grades & GPA row (pushed) (D-19) |
| `/grades/new`, `/grades/[id]/edit` | `GradeFormView` sheet | Grades |
| `/settings` | `ProfileView`, settings below your profile (D-19) | Tab 4 ("Profile") |
| `/settings/deleted` | `RecentlyDeletedView` | Settings |
| `/prompt` | `PostClassPrompt`, a card over the app (D-34) | Tapping the after-class notification, or Today's Log it (7c) |
| `/lock` | none (Replace, see section 0) | |
| `/upgrade` | none (it's a redirect) | |
| `/`, `/sso-callback` | `SignInView` (Phase 14). Until then the app opens straight into Today | |
| `/dev/godmode` | `SamplePlanner` loader, debug builds only | Settings, hidden row |
| everything in `app/(site)`, `/admin`, `/email/dismissed` | Skip | |

Navigation is state in SwiftUI: one `TabView`, a `NavigationStack` per tab, `.sheet` for forms. A notification tap sets `store.route` (an `AppRoute`, 7c), which RootView carries out: Today, a task's detail through the Tasks tab's `NavigationPath`, or the prompt as an overlay (D-33, D-34).

---

## 3. Data

Rules that apply to every model: Codable struct, `id: UUID` (Kelvin's existing models use `UUID`, and Supabase's `uuid` columns accept it; changed from `String` on 2026-10-13), field names mirror the Supabase column in camelCase, and `user_id` is never stored on the model. The sync mapper adds it, exactly as `classToRow(c, userId)` does. `rev` and `updated_at` are server-owned and only appear in Phase 14.

Wire formats come from `lib/supabase/map.ts`: dates are `"YYYY-MM-DD"` strings, times of day are `"HH:mm"` (Postgres returns `"HH:mm:ss"`, `fromDbTime` cuts it to 5 characters), soft-delete and snooze are instants (`timestamptz`), and the web keeps those as epoch milliseconds. Swift uses `Date?` for instants and `String?` for dates and times, never `Date` for a deadline.

### 3.1 `classes` → `Course` (23 client-owned columns)

| Column | TypeScript (`ClassItem`) | Swift | Notes |
|---|---|---|---|
| `id` | `id: string` | `id: UUID` | |
| `user_id` | (not on item) | (not on model) | Added by the sync mapper |
| `name` | `string` | `name: String` | |
| `short` | `string` | `short: String` | Short code, e.g. "BIO" |
| `color` | `SubjectColor` | `color: SubjectColor` | Enum, 9 cases: amber, indigo, coral, teal, pink, violet, mint, ocean, slate |
| `days` | `DayIndex[]` | `days: [Int]` | 0 = Monday ... 6 = Sunday |
| `additional_meetings` | `ClassMeeting[]?` | `additionalMeetings: [ClassMeeting]` | `ClassMeeting {id, days, start, end, room?, label?}`, max 20. Empty array = none |
| `start_min` | `start: number` | `startMin: Int` | Minutes from midnight |
| `end_min` | `end: number` | `endMin: Int` | |
| `remind_before` | `remindBefore: number` | `remindBefore: Int` | Minutes before class |
| `alarm` | `boolean` | `alarm: Bool` | Pre-class alarm on or off |
| `extra_reminders` | `reminders?: number[]` | `extraReminders: [Int]` | Renamed on the web, keep the column name |
| `credits` | `number?` | `credits: Double?` | nil counts as 1 in GPA |
| `room` | `string?` | `room: String?` | |
| `instructor` | `string?` | `instructor: String?` | |
| `notes` | `string?` | `notes: String?` | Free text on the class, not the Notes feature |
| `term` | `string?` | `term: String?` | nil = current term |
| `archived` | `boolean?` | `archived: Bool` | |
| `goal` | `number?` | `goal: Double?` | Target percent |
| `source_feed` | `string?` | `sourceFeed: String?` | Feed provenance, Phase 13 |
| `source_uid` | `string?` | `sourceUID: String?` | |
| `source_hash` | `string?` | `sourceHash: String?` | |
| `deleted_at` | `deletedAt?: number` (ms) | `deletedAt: Date?` | Soft delete |

**Missing today:** 13 of these (IOS_APP.md says Course has 10). Phase 1 adds the rest with defaults so Kelvin's sample data still compiles.

### 3.2 `tasks` → `Assignment` (20 client-owned columns)

| Column | TypeScript (`TaskItem`) | Swift | Notes |
|---|---|---|---|
| `id` | `string` | `id: UUID` | |
| `user_id` | | | Mapper |
| `class_id` | `classId: string` ("" = Inbox) | `courseID: UUID?` | **nil = Inbox.** The web uses "", Swift uses nil, the mapper converts |
| `title` | `string` | `title: String` | |
| `due` | `string \| null` | `due: String?` | **Must become optional.** nil = Inbox / undated |
| `due_time` | `dueTime?: string \| null` | `dueTime: String?` | `"HH:mm"`. nil = all-day, never 23:59 |
| `reminder` | `boolean` | `reminder: Bool` | Daily nag from 24 h out |
| `done` | `boolean` | `done: Bool` | On screen: "Complete" / "Completed" |
| `kind` | `"assignment"\|"quiz"\|"exam"\|"reminder"?` | `kind: Assignment.Kind` | Default `.assignment` (undefined on the web means assignment) |
| `notes` | `string?` | `notes: String?` | |
| `subtasks` | `TaskSubtask[]?` | `subtasks: [Subtask]` | `Subtask {id, title, done}` |
| `remind_leads` | `number[]?` | `remindLeads: [Int]` | Empty = "not chosen", which gives exams the 1 week / 3 day / 2 day ladder (`effectiveLeads`) |
| `snoozed_until` | `snoozedUntil?: number` (ms) | `snoozedUntil: Date?` | An instant, unlike `due` |
| `repeat_rule` | `repeat?: "weekly"\|"monthly"` | `repeatRule: RepeatRule?` | |
| `repeat_until` | `string?` | `repeatUntil: String?` | Date string |
| `recurrence_parent_id` | `string?` | `recurrenceParentID: UUID?` | Stops duplicate follow-ups |
| `source_feed` / `source_uid` / `source_hash` | `string?` | `sourceFeed`, `sourceUID`, `sourceHash: String?` | |
| `deleted_at` | ms | `deletedAt: Date?` | |

**Missing today:** 12 of these (Assignment has 8). The breaking one is `due`, which must change from `Date` (or `String`) to `String?`.

### 3.3 `grades` → `Grade` (10)

`id: UUID`, `courseID: UUID?` (`class_id`), `title: String`, `score: Double`, `max: Double`, `weight: Double` (percent within the class), `date: String`, `kind: GradeKind?` (exam, quiz, assignment, project; nil on old grades), `deletedAt: Date?`. Plus `user_id` from the mapper.

### 3.4 `notes` → `Note` (8)

`id: UUID`, `courseID: UUID?` (nil = quick note), `date: String` (lecture day), `title: String` (empty = falls back to first line), `body: String` (the markdown dialect in `lib/notes.ts`), `assignmentID: UUID?` (`task_id`), `deletedAt: Date?`. Plus a local-only `updatedAt: Date` (the web keeps it for the cache; the server owns the column).

### 3.5 `task_plans` → `TaskPlan` (5)

`id: UUID`, `assignmentID: UUID` (`task_id`, required), `date: String` (work day, never touches `due`), `priority: Int?` (1 to 3, nil = just planned). Local `updatedAt: Date`. One plan per task (unique user/task).

### 3.6 `study_sessions` → `StudySession` (7)

`id: UUID`, `assignmentID: UUID?`, `courseID: UUID?`, `minutes: Int` (1 to 240), `completedAt: Date`, `mode: StudyMode` (`.timer`, `.pomodoro`). Breaks are never recorded.

### 3.7 `profiles` → `Profile` (18 client-owned, plus `tz`)

| Column | Swift | Notes |
|---|---|---|
| `username` | `username: String` | |
| `avatar_url` | `avatarURL: String?` | Upload goes through `/api/avatar` |
| `theme` | `theme: AppTheme` | `.light`, `.dark` |
| `accent` | `accent: Profile.Accent` | `.babypink` (default), `.ocean` |
| `style` | (not modeled) | Legacy, the mapper always writes `"soft"` |
| `post_class_nudge` | `postClassNudge: Bool` | Default true |
| `quiet_start`, `quiet_end` | `quietStart: Int?`, `quietEnd: Int?` | Minutes. Both nil = never quiet. Wraps when start > end |
| `finals_date` | `finalsDate: String?` | |
| `grade_scale` | `gradeScale: GradeScaleID?` | `.standard`, `.simple`, `.custom` |
| `term_start`, `term_end` | `termStart`, `termEnd: String?` | |
| `term_name` | `termName: String?` | |
| `term_setup_prompted` | `termSetupPrompted: Bool` | |
| `import_feeds` | `importFeeds: [SavedFeed]` | `{id, url, label, lastSyncedAt}`, max 5 |
| `custom_scale` | `customScale: [ScaleBand]` | `{min, letter, points}`, max 16 |
| `quotes` | `quotes: [String]` | Empty = built-in rotation |
| `tz` | (not on model) | Written out of band at sync: `TimeZone.current.identifier` |

The web also carries a retired `frame` field. Don't port it.

### 3.8 `game_state` → `GameState` (2: `user_id`, `data`)

`data` is one JSON blob: `{ trophies, xp, pet, boss }`. Swift: `struct GameState: Codable { var trophies: TrophyState?; var xp: XpState?; var pet: PetState? }`, ported from `lib/trophies.ts`, `lib/xp.ts` and `lib/pet.ts` in Phase 12. The boss fight is left out, but sync must carry `boss` through untouched (keep it as raw JSON) so the phone never erases the web's boss state.

### 3.9 The planner document

`planner.json` holds one `PlannerDocument { courses, assignments, grades, notes, taskPlans, studySessions, profile, game }`, saved after every change before any network call. That's the Swift version of the `classping.v1:<id>` document. Deleted items stay in the arrays with `deletedAt` set; the store exposes filtered computed properties (`courses`, `assignments`...) the way the web's memos do.

---

## 4. Logic (`lib/`)

Every non-test file in `lib/`, once. "Test" is the web test file whose cases get a Swift Testing twin in `docs/ios/reference/Tests/Logic/`.

### 4.1 Port, into `Sources/ClassPing/Logic/` (Foundation only)

| Web file | Swift file | Web test | Phase |
|---|---|---|---|
| `lib/time.ts` | `Logic/Time.swift` (plus `dueLabel`, `longDate`, `weekInfo`, `fmtMD` from the bottom of `store.tsx`; `justEndedClass` went to `Logic/PostClass.swift` in 7c, with its first caller) | `time.test.ts` | 2 |
| `lib/deadline.ts` | `Logic/Deadline.swift` (plus `taskDeadline`, `taskDueAt`, `byDeadline`, `normalizeTask` from `store.tsx`) | `deadline.test.ts` | 2 |
| `lib/palette.ts` | `Logic/Palette.swift` (`SubjectColor` names; the colors live in `Theme.swift`) | none | 1 |
| `lib/accents.ts` | `Profile.Accent` (Phase 1) + its colors in `Design/Theme.swift` | `accents.test.ts` | 3 |
| `lib/class-meetings.ts` | `Logic/ClassMeetings.swift` | `class-meetings.test.ts` | 5 |
| `lib/task-view.ts` | `Logic/TaskView.swift` | `task-view.test.ts` | 4 |
| `lib/planning.ts` | `Logic/Planning.swift` | `planning.test.ts` | 4a (`nextRepeatDate`), 7b (`studyMinutes`; `localDateKey` is `dayOf`), the normalisers with Phase 11 / 14, `plansForDate` and `priorityPlans` not ported (D-23, D-31) |
| `lib/quotes.ts` | `Logic/Quotes.swift` | `quotes.test.ts` | 6a |
| `lib/reminders.ts` | `Logic/Reminders.swift` (the rules), plus `Logic/ReminderPlan.swift`, which replaces `dueReminders` and the store's 30-second loop by planning ahead (D-28) | `reminders.test.ts` (as `RemindersTests`, the `dueReminders` cases asked of the planner) + `ReminderPlanTests` (phone-only) | 7a |
| `lib/exam-prep.ts` | `Logic/ExamPrep.swift` | `exam-prep.test.ts` | 7b |
| `lib/notes.ts` | `Logic/Notes.swift`: the limit, `stripMarkers`, titles, previews, `dayLabel`, plus the search and live-class checks from `app/classes/page.tsx` (8a); `parseBlocks`, `escapeHtml`, `safeHref`, `inlineToHtml` in `Logic/NoteMarkdown.swift`, with `inlineRuns` reading the HTML back as styled runs (8b). `htmlToMd`, `mdToHtml`, `noteColorOf` are browser-only (Skip); `normalizeNotes`, `mergeNotes`, `conflictTitle` wait for Phase 11 / 14 (D-31) | `notes.test.ts` (as `NotesTests`) | 8a, 8b |
| `lib/highlight.ts` | Not ported: it is DOM surgery on the web reader's page. A highlight is the `==` marker, typed by 8c's bar | none | 8c |
| `lib/tidy-note.ts` | `tidyNote` in `Logic/NoteTidy.swift` | `tidy-note.test.ts`, plus 13 web-checked notes | 8c |
| `lib/note-tidy.ts` | merged into `Logic/NoteTidy.swift` (only the shapes `tidy-note.ts` imports; the OpenAI half stays on the server) | `note-tidy.test.ts` (shape cases only) | 8c |
| `lib/line-diff.ts` | `lineDiff` in `Logic/NoteTidy.swift` (the tidy preview) | `line-diff.test.ts` | 8c |
| `lib/gpa.ts` | `Logic/GPA.swift` (9a averages/bands/credits/budgets; 9b projections/what-if/editor validation) | `gpa.test.ts` → `GPATests.swift` (complete since 9b) | 9a, 9b |
| `lib/report.ts` | `Logic/GradeReport.swift` (CSV only, with `jsNumber`/`jsFixed`), shared from `Screens/Grades/TermReportCard.swift` (`ShareLink`) | `report.test.ts` (CSV cases) → `GradeReportTests.swift`, plus a whole-file check against the web's output | 9c |
| `lib/study.ts` | `Logic/Study.swift` | `study.test.ts` | 10 |
| `lib/streak.ts` | `Logic/Streak.swift` | `streak.test.ts` | 6b (D-26) |
| `lib/xp.ts` | `Logic/XP.swift` | `xp.test.ts` | 12 |
| `lib/pet.ts` | `Logic/Pet.swift` | `pet.test.ts` | 12 |
| `lib/trophies.ts` | `Logic/Trophies.swift` | `trophies.test.ts` | 12 |
| `lib/boss.ts` | **Skip** (Kelvin, 2026-10-13: no boss fight) | | |
| `lib/backup.ts` | `Logic/Backup.swift` (same JSON format, so a web backup restores on the phone) | `backup.test.ts` | 11 |
| `lib/recovery.ts` | `Logic/Recovery.swift` (30-day window) | none | 11 |
| `lib/calendar.ts` | `Logic/CalendarExport.swift` (ICS text, shared with `ShareLink`) | `calendar.test.ts` | 11 |
| `lib/ics-import.ts` | `Logic/ICSImport.swift` (not `planImport`, D-80) | `ics-import.test.ts` | 13a |
| `lib/ics-reconcile.ts` | `Logic/FeedReconcile.swift` (generic over `FeedLocalRow`, D-104) | `ics-reconcile.test.ts` → `FeedReconcileTests.swift`, fingerprints in `WebValues14e.swift` | 14e |
| `lib/feeds.ts` | `Logic/ServerValues.swift` (`MAX_FEEDS`, `feedLabelFromURL`, 14b), `normalizeFeeds` in `Models+Rows.swift` (14b), the rest in `Store+Feeds.swift` | `feeds.test.ts` → `FeedStoreTests.swift` | 14b, 14e |
| `lib/csv-import.ts` | `Logic/CSVImport.swift` | `csv-import.test.ts` | 13a |
| `lib/paste-schedule.ts` | `Logic/PasteSchedule.swift` | `paste-schedule.test.ts` | 13b |
| `lib/merge.ts` | `Logic/Merge.swift` (three-way merge) | `merge.test.ts` | 14a (D-89) |
| `lib/sync.ts` | `Logic/SyncStatus.swift` (what the app may claim) | none (`sync-contract.test.tsx` journey) | 14a (D-89) |
| `lib/supabase/columns.ts` | `Logic/Columns.swift` | `supabase/columns.test.ts` | 14a (D-89) |
| `lib/supabase/map.ts` | `Logic/RowMapping.swift` (row structs with snake_case `CodingKeys`) | covered by `columns.test.ts` | 14b (D-89) |
| `lib/godmode.ts` | `Logic/SamplePlanner.swift` (the busy-semester and weekend fixtures) | `godmode.test.ts` | 16 |

### 4.2 Rebuild

| Web file | Swift | Notes |
|---|---|---|
| `lib/store.tsx` | `Store.swift` + `Store+Courses.swift`, `Store+Assignments.swift`, `Store+Grades.swift`, `Store+Notes.swift`, `Store+Profile.swift` (11a: `archiveTerm` and the profile writes), `Store+Planning.swift`, `Store+Progress.swift`, `Store+Trash.swift`, `Store+Persistence.swift`, `Store+Notifications.swift`, `Store+Sync.swift` | Same action names as the web `Store` interface (`addClass` becomes `addCourse`, `toggleTask` becomes `toggleAssignment`, and so on). Pure helpers at the bottom of the file are Ported (4.1) |

### 4.3 Replace

| Web file | iOS equivalent |
|---|---|
| `lib/notifications.ts` | `UNUserNotificationCenter` in `Store+Notifications.swift` (7a). Permission is asked the first time there's something to ring; the "Reminder set ✓" test notification is dropped (D-30) |
| `lib/push.ts` | Same, local notifications (no APNs on a free account) |
| `public/sw.js`, its `notificationclick` | `didReceive` in `ClassPingApp.swift`, `notificationRoute` in `Logic/PostClass.swift` and `go` in `RootView.swift` (7c): a post-class nudge opens the prompt, a task's reminder its detail, a class alarm Today (D-33) |
| `lib/ambient.ts` | `Logic/Ambient.swift` (the voices, `synthesize`, `encodeWav`, tested against the web's samples) and `Audio/AmbientPlayer.swift` (`AVAudioPlayer`, the lock screen), 10b (D-64) |
| `lib/avatar.ts` | `Logic/Avatar.swift` (limits, `isPersistableAvatar`, the messages, 11a) and `avatarURI(from:)` in `ProfileCard.swift` (`PhotosPicker` + the 256 px JPEG crop, kept as a `data:` address, D-65); the `/api/avatar` upload is `WebAPI.uploadAvatar` in `ProfileCard.use`, with `versionedAvatarURL`, and https photos draw through `AvatarLoader` (14e, D-105) |
| `lib/schedule-file.ts` | `.fileImporter` / `PhotosPicker` + PDFKit page renders for the schedule upload |
| `lib/pdf.ts` | Not needed on the phone: the PDF grade report comes from `/api/export/grades` (D-6) |
| `lib/themeColor.ts`, `lib/themeHint.ts` | `.preferredColorScheme` and `.tint` at the root |
| `lib/useDraft.ts` | Draft structs saved in `drafts.json` (or `@SceneStorage` for single fields) |
| `lib/useMediaQuery.ts` | Not needed: one phone layout |
| `lib/ai-consent.ts` | `UserDefaults` key `ai-consent.<feature>.<version>` |

### 4.4 Connect (the server keeps the work, the phone calls it)

| Web file | Why it stays on the server | Swift caller |
|---|---|---|
| `lib/task-extract.ts` | Holds the OpenAI schema for `/api/parse/task` | `API/ParseTaskAPI.swift` (response decoded into a struct) |
| `lib/schedule-extract.ts` | Same, for `/api/import/schedule` | `API/ScheduleImportAPI.swift` |
| `lib/useAiAvailability.ts` | Asks `/api/ai/status` which AI features are configured | `API/AIStatusAPI.swift` |
| `lib/supabase/client.ts` | Becomes a supabase-swift client fed the Clerk token | `Sync/SupabaseClient.swift` (Phase 14) |

### 4.5 Skip (read, never port)

Server-only or web-only: `lib/adminAuth.ts`, `lib/avatar-server.ts`, `lib/calendar-fetch.ts`, `lib/url-guard.ts` (both part of the `/api/import/ics` server guard), `lib/cron-auth.ts`, `lib/cron-schedule.ts`, `lib/db.ts`, `lib/email.ts`, `lib/email-delivery.ts`, `lib/entitlements.ts`, `lib/plan.ts`, `lib/useIsPro.ts` (legacy Pro), `lib/godmodeAccess.ts`, `lib/ratelimit.ts`, `lib/redirect.ts`, `lib/request-body.ts`, `lib/request-security.ts`, `lib/site.ts`, `lib/svix.ts`, `lib/shell.ts` (Tauri), `lib/supabase/admin.ts` (service role, never on a phone), `lib/server/note-tidy-budget.ts`, `lib/server/note-tidy-openai.ts`, `lib/server/schedule-budget.ts`, `lib/server/schedule-openai.ts`, `lib/server/task-budget.ts`, `lib/server/task-openai.ts`.

Test-only files with no source twin (security, API and tooling tests) are Skip too.

**Count check:** 79 source files in `lib/`. Port 35, Rebuild 1, Replace 11, Connect 4, Skip 28 = 79 (the boss fight moved to Skip on 2026-10-13).

---

## 5. Screens and components

### 5.1 `app/`

| Web file | Bucket | SwiftUI |
|---|---|---|
| `app/home/page.tsx` | Rebuild | `Screens/Today/TodayView.swift` + `ClassCard.swift` (6a) + `TodaySections.swift` (6b): the picked day's class cards and messages, the quote banner, the term glance, the four soonest assignments, My Classes. No priorities or planned-work card: the web dropped them (D-23). The pet card is Phase 12; the post-class banner is `justEndedBanner` (7c); Grades and Settings moved to the Profile tab (D-19) |
| `app/week/page.tsx` | Rebuild | `Screens/Week/WeekStrip.swift` + `WeekGrid.swift` (5a) + `CourseSheet.swift` (5b), hosted by Today (D-19) |
| `app/tasks/page.tsx` | Rebuild | `Screens/Tasks/TasksView.swift` |
| `app/tasks/new/page.tsx` | Rebuild | `Screens/Tasks/AssignmentFormView.swift` |
| `app/tasks/[id]/edit/page.tsx` | Rebuild | same `AssignmentFormView` in edit mode |
| `app/tasks/[id]/page.tsx` | Rebuild | `Screens/Tasks/AssignmentDetailView.swift` (linked notes and Open {class} since 8d) |
| `app/classes/page.tsx` | Rebuild | `Screens/NotesView.swift` (the first pane) and `Screens/Notes/CourseNotesView.swift` (`NoteListPane`), 8a; `NotePane`'s quick task buttons and `QuickTaskCard`, 8d (`Screens/Notes/QuickTaskSheet.swift`, `Logic/QuickTask.swift`, D-45) |
| `app/class/new/page.tsx` | Rebuild | `Screens/Courses/CourseFormView.swift` |
| `app/class/[id]/edit/page.tsx` | Rebuild | same `CourseFormView` in edit mode |
| `app/grades/page.tsx` | Rebuild | `Screens/Grades/GradesView.swift` |
| `app/grades/new/page.tsx` | Rebuild | `Screens/Grades/GradeFormView.swift` |
| `app/grades/[id]/edit/page.tsx` | Rebuild | same `GradeFormView` in edit mode |
| `app/settings/page.tsx` | Rebuild | the Profile tab, `Screens/ProfileView.swift` (D-19) (profile, appearance, reminders, quiet hours, email prefs, term, grade scale, imports, backup, export, review, account). The Reminders card is `Screens/Profile/RemindersSection.swift` (7a); in 11a the Profile card is `Screens/Profile/ProfileCard.swift`, the grading card `Screens/Profile/GradingSection.swift` (moved from the Grades screen, D-67), the Semester card with `CurrentTerm` and `DateBox` `Screens/Profile/SemesterSection.swift` + `Logic/Term.swift`, and the profile and term writes `Store+Profile.swift` |
| `app/settings/deleted/page.tsx` | Rebuild | `Screens/Settings/RecentlyDeletedView.swift` |
| `app/prompt/page.tsx` | Rebuild | `Screens/Prompt/PostClassPrompt.swift` (7c): the question, the sign-off and "No class just ended" as one card over the app (D-34); `nextClassToday` in `Logic/PostClass.swift`, over the active classes (D-35) |
| `app/page.tsx` | Rebuild (Phase 14) | `Screens/Account/SignInView.swift`. The marketing half is Skip |
| `app/sso-callback/page.tsx` | Replace | Clerk iOS SDK handles OAuth callbacks |
| `app/lock/page.tsx` | Replace | The real iOS lock screen |
| `app/layout.tsx` | Replace | `ClassPingApp.swift` + `RootView.swift` (fonts, theme, accent at the root) |
| `app/globals.css` | Replace | `Design/Theme.swift` (section 6); the `.note-body` styles in `Design/Theme+Notes.swift` and `Screens/Notes/NoteReaderView.swift` (8b) |
| `app/manifest.ts`, `app/icon.png`, `app/apple-icon.png` | Replace | App icon (an unknown with xtool, see PHASES) |
| `app/not-found.tsx` | Skip | No URLs to miss |
| `app/upgrade/page.tsx` | Skip | Redirect only |
| `app/opengraph-image.tsx`, `app/robots.ts`, `app/sitemap.ts` | Skip | SEO |
| `app/email/dismissed/page.tsx` | Skip | Email landing page |
| `app/dev/godmode/page.tsx`, `app/dev/godmode/GodmodePanel.tsx` | Skip (the data is Ported as `SamplePlanner`) | |
| `app/admin/page.tsx`, `AdminBoard.tsx`, `AdminLogin.tsx` | Skip | |
| `app/(site)/layout.tsx`, `about`, `download`, `feedback`, `getting-started` (page + `page.module.css`), `privacy`, `terms`, `welcome` | Skip | Marketing. Settings links out to `/privacy` and `/terms` in Safari |
| `app/api/parse/task/route.ts` | Connect | `ParseTaskAPI` (quick add) |
| `app/api/import/schedule/route.ts` | Connect | `ScheduleImportAPI` |
| `app/api/import/ics/route.ts` | Connect | `WebAPI.readFeed`, answer read by `importResult(fromServer:)` (D-7, D-103), 14e |
| `app/api/ai/status/route.ts` | Connect | `AIStatusAPI` |
| `app/api/avatar/route.ts` | Connect | `WebAPI.uploadAvatar` (D-105), 14e |
| `app/api/account/route.ts` | Connect | `WebAPI.deleteAccount`, `deleteOutcome` (D-106), 14e |
| `app/api/feedback/route.ts` | Connect | `WebAPI.sendReview` (review card, signed in, D-103), 14e |
| `app/api/email/prefs/route.ts` | Connect | `WebAPI.emailPrefs` / `setEmailPrefs`, `EmailPrefs` (D-107), 14e |
| `app/api/export/grades/route.ts` | Connect | PDF grade report (D-6) |
| `app/api/export/route.ts` | Skip | Replaced by the Ported `CalendarExport` |
| `app/api/notes/tidy/route.ts` | Skip | No longer called by the client |
| `app/api/push/subscribe/route.ts` | Skip | Web push only |
| `app/api/email/unsubscribe/route.ts` | Skip | Email link target |
| `app/api/admin/session/route.ts`, `app/api/webhooks/clerk/route.ts` | Skip | |
| `app/api/cron/assignment-email`, `daily-email`, `post-class`, `post-class-email`, `pre-class-email`, `weekly-email` (all `route.ts`) | Skip | Server schedules |

### 5.2 `components/`

| Component | Bucket | SwiftUI |
|---|---|---|
| `TabBar.tsx` | Rebuild | `RootView.swift` (`TabView` + center Add button) |
| `AddMenu.tsx` | Rebuild | `Components/AddMenu.swift` (Note opens the Notes tab since 8d, D-46) |
| `Sidebar.tsx` | Skip | Desktop only |
| `PhoneFrame.tsx` | Replace | The device itself; safe areas are automatic |
| `StatusChrome.tsx` | Rebuild | `Components/UndoBar.swift` (the undo-delete bar, 4b, shared with Today in 6b, D-25); the save/sync state comes with sync in Phase 14 |
| `Skeleton.tsx` | Replace | `.redacted(reason: .placeholder)` |
| `Toggle.tsx` | Replace | SwiftUI `Toggle` with `.tint` |
| `icons.tsx` | Replace | SF Symbols (`Components/Icons.swift` names them in one place) |
| `SubjectBook.tsx` | Rebuild | `Components/SubjectBook.swift` (the subject-book image the rules say to keep), 6a |
| `ColorPicker.tsx` | Rebuild | `Components/ColorPicker.swift` (no locks: everything is free) |
| `ClassForm.tsx` | Rebuild | `CourseFormView.swift`; the import button and the term question after a first class in 13b |
| `MeetingFields.tsx` | Rebuild | `Components/MeetingFields.swift` |
| `ExtraReminders.tsx` | Rebuild | `Components/ExtraReminders.swift` |
| `TermSetupSheet.tsx` | Rebuild | `Screens/Import/TermSetupSheet.swift`, 13a (after a first class from 13b) |
| `QuickAddTask.tsx` | Rebuild | `Screens/Tasks/QuickAddBar.swift` (calls `/api/parse/task`, Phase 15) |
| `TaskFilterBar.tsx` | Rebuild | `Screens/Tasks/TaskFilterBar.swift` (filters saved in `UserDefaults`) |
| `TaskReminders.tsx` | Rebuild | `Screens/Tasks/TaskReminderCard.swift` and `ExamPrepCard` in `Screens/Tasks/PlanningCards.swift` (shown only for a dated exam, D-32), 7b. The store side is `Store+Planning.swift` |
| `StudyTimer.tsx` | Rebuild | `Screens/Study/StudyTimerView.swift` and `Screens/Study/StudySetupView.swift` (10a, D-62); its `clock`, `span` and alert words in `Logic/Study.swift`; the sound picker in 10b |
| `QuoteBanner.tsx` | Rebuild | `Screens/Today/QuoteBanner.swift`, 6a |
| `FinalsCountdown.tsx` | Rebuild | `Screens/Grades/FinalsCountdown.swift`, its count and words in `Logic/Finals.swift` (local calendar days, D-56), 9c |
| `NoteEditor.tsx` | Rebuild | `Screens/Notes/NoteView.swift`: plain markdown in a `TextEditor` (D-2, D-37) with the web editor's saving, 8a; its formatting bar, `Screens/Notes/NoteFormatBar.swift` with `Logic/NoteFormat.swift`, 8c (D-41) |
| `NoteReader.tsx` | Rebuild | `Screens/Notes/NoteReaderView.swift` (8b), the note's first view, with Edit (D-37) |
| `NoteTidyButton.tsx` | Rebuild | Tidy note above the reader (`Screens/Notes/NoteView.swift`) and `Screens/Notes/NoteTidySheet.swift` (on-device, with the `lineDiff` preview), 8c (D-41) |
| `GradeFields.tsx` | Rebuild | `Screens/Grades/GradeFields.swift` |
| `GradeScaleEditor.tsx` | Rebuild | `Screens/Grades/GradeScaleEditor.swift` (9b), its draft rows in `Logic/ScaleDraft.swift` (`ScaleDraftTests.swift`); pushed from the Grades scale card (D-51) |
| `QuietHours.tsx` | Rebuild | inside `Screens/Profile/RemindersSection.swift` with the after-class nudge switch, 7a |
| `RestoreSheet.tsx` | Rebuild | `Screens/Settings/RestoreSheet.swift` |
| `ReviewCard.tsx` | Rebuild | `Screens/Profile/ReviewCard.swift`, 14e |
| `ImportCalendar.tsx` | Rebuild | `Screens/Import/ImportView.swift` (`ImportPanel`, `ImportCard`, `ImportSheet`), 13a; Paste a timetable and `onImported` in 13b; the feed half in 14e (D-79, D-104) |
| `FeedRefresh.tsx` | Rebuild | `Screens/Import/FeedRefreshView.swift`, 14e |
| `PasteSchedule.tsx` | Rebuild | `Screens/Import/PasteScheduleView.swift`, 13b, a sheet of its own (D-84); the `initialRows` review of a screenshot or PDF in 15 |
| `ScheduleUpload.tsx` | Rebuild | `Screens/Import/ScheduleUploadView.swift` |
| `ClassPet.tsx` | Rebuild | `Screens/Progress/ClassPetView.swift` (needs the pet art as resources) |
| `Level.tsx` | Rebuild | `Screens/Progress/LevelView.swift` |
| `Trophies.tsx` | Rebuild | `Screens/Progress/TrophiesView.swift` |
| `BossFight.tsx` | Skip | Left out (Kelvin, 2026-10-13) |
| `DisplayCase.tsx` | Skip | Desktop `xl` rail only; its pieces already appear on Today |
| `InstallPrompt.tsx`, `PhoneInstall.tsx` | Skip | Install prompts aren't needed |
| `ShellUpdateNotice.tsx` | Skip | Tauri |
| `AuthCookieSync.tsx` | Skip | Web cookie for the landing redirect |
| `CopyPrompt.tsx`, `SiteNav.tsx`, `JsonLd.tsx`, `Legal.tsx`, `FeedbackForm.tsx` | Skip | Marketing site |

**Count check:** 64 files in `app/` (including the two PNGs, `globals.css` and the CSS module) and 46 in `components/`, all listed above.

---

## 6. Design: `app/globals.css` → `Design/Theme.swift`

| Token | Light | Dark | Swift |
|---|---|---|---|
| Brand (Baby Pink) | `#E85D8A`, deep `#C43D6E`, bright `#FF8FB0`, dark `#A8285E` | brand-dark `#F5A6C0` | `Theme.brand(accent:)` |
| Brand (Ocean) | `#3B82C4`, deep `#2A6BA8`, bright `#6BA8E0`, dark `#1D4E78` | brand-dark `#A4C9EA` | |
| Brand gradient | 135°, bright to deep | same | `LinearGradient(.topLeading → .bottomTrailing)` |
| Brand soft | brand at 16% | 22% | `.opacity(0.16 / 0.22)` |
| Ink / muted / faint / hint | `#3A3530` / `#6B6458` / `#847B6D` / `#948B7E` | `#FFFFFF` / `#C9C1BC` / `#A59994` / `#928780` | `Theme.ink`, `.muted`, `.faint`, `.hint` |
| Canvas / card / outer | `#EDEAE4` / `#EDEAE4` / `#F5F3EF` | `#26232A` / `#26232A` / `#211F24` | `Theme.canvas`, `.card`, `.outer` |
| Neumorphic shadows | dark `rgba(166,157,140,.5)`, light `rgba(255,255,255,.85)`; raised `6 6 14` both ways; inset `3 3 7` | `#171519` / `#322E37` | `.neuRaised()` and `.neuInset()` view modifiers (two `.shadow`s each) |
| Lines, chip, active pill | `#DCD6CB`, `#C6BEAF`, `#F0EDE7`, `#F2EFE9` | 12% / 28% white-ish, `#342E36`, `#3C353E` | `Theme.line`, `.lineStrong`, `.chip`, `.pillActive` |
| Semantic | good `#6F9C65`, warn ink `#886221`, danger `#C9514D`, info ink `#365D7D` (+ soft/ink pairs) | lighter twins | `Theme.good`, `.warn`, `.danger`, `.info` (each with `.soft`, `.ink`) |
| Subject colors | `--subj-<name>-bg / -text / -sub` for 9 names | low-alpha washes | `SubjectColor.bg / .text / .sub` per scheme |
| Trophy tiers | bronze / gold / platinum soft | 20% washes | `Theme.trophy(tier)` |
| Card radius | `rounded-[15px]` is the most used (61 uses), then 13, 18, 14 px; sheets 20 and 24 px | | `Theme.radius.card = 15`, `.small = 13`, `.large = 18`, `.sheet = 24` |
| Type | Archivo (Google font), body 15.5 px, headings 26 / 21 / 17.5 px, tab labels 9.5 px semibold | | `Theme.font` (D-8: bundle Archivo or use SF Pro) |
| Dark mode | `html.dark` class | | `@Environment(\.colorScheme)` plus `profile.theme` forcing it |

Shared components become small views or modifiers: card surface → `.cardStyle()`; inset input → `.insetField()`; subject chip → `SubjectChip`; section header → `SectionHeader`; empty state → `EmptyState(title:message:action:)`.

---

## 7. Decisions for Kelvin (needed before Step 2)

| # | Question | Recommendation | Why |
|---|---|---|---|
| D-1 | **Tabs:** designs (Week + Tasks) or the web app (Today, Notes, +, Planner, Tasks)? | Match the web app | It's the newer source, the product rules name those words, and Grades and Settings already hang off Today |
| D-2 | **iOS target:** stay on 18, or raise it? | Stay on 18 | Notes are plain markdown text, which `TextEditor` handles on 18. The rich `AttributedString` editor is iOS 26+, and it would also change the stored format |
| D-3 | **Order of the big features** after Tasks / Planner / Today / Reminders | Notes, Grades, Study timer, Settings + backup, Pet & gamification, Imports, Sign-in & sync, AI | Daily use first; sync last because every model must be final |
| D-4 | **Leave out for now?** | Leave out: boss fight, ambient sound, schedule-photo AI import, avatar upload | Each is large and none blocks daily use. They stay in the map, just later |
| D-5 | **Sign-in at all?** Phases 1 to 13 work signed out. | Yes, but last | Needs the Clerk iOS SDK and supabase-swift to build under xtool, which is untested |
| D-6 | **Grade report PDF:** call the server or skip? | CSV on device now, server PDF later | CSV is a Port with tests; the PDF needs sign-in |
| D-7 | **Calendar feed refresh:** through `/api/import/ics`, or fetch the URL from the phone? | Through the server | The server route has the size, redirect and timeout limits already; doing it on the phone means re-porting them |
| D-8 | **Font:** bundle Archivo, or use the system font? | System font (SF Pro) until resources are tested | Bundling a font is one of the untested xtool unknowns |
