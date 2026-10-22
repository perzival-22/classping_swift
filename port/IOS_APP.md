# ClassPing iOS: how it's built, and what to do next

*Last checked on Kelvin's laptop (kelvianapc) on 2026-10-13.*

This file does two jobs:

1. **For Kelvin:** it explains how a Windows laptop builds a real iPhone app and puts it on the phone, with no Mac involved.
2. **For Claude (any session working in this folder):** it sets the rules and hands over the task. That task is to map the ClassPing web app, then plan and deliver its Swift version in phases. Kelvin typed every file himself through 14a; from 14b Claude applies each verified phase on a branch and Kelvin reviews and merges it (D-93, section 3.2).

**Claude, read this whole file before you do anything. Section 3 is binding.**

**Kelvin, start each new session by saying:** "Read IOS_APP.md and docs/ios/PROGRESS.md, then continue."
(On the very first session there's no PROGRESS.md yet, so say "Read IOS_APP.md and start Step 1.")

---

## 1. The short version

| | |
|---|---|
| **What** | A native SwiftUI version of ClassPing, the web app in this folder, for Kelvin's own iPhone. |
| **Why** | To learn Swift and iOS development by rebuilding an app Kelvin already knows inside out. |
| **How** | Windows → WSL (Ubuntu) → Swift 6.4 + xtool → USB through usbipd → iPhone. No Mac, no Xcode app. |
| **Web app (source of truth)** | `C:\Users\kelvi\Desktop\classping` (this folder) |
| **iOS project** | `/home/wilch/ClassPing` inside WSL. From Windows it's `\\wsl.localhost\Ubuntu\home\wilch\ClassPing` |
| **Golden rule** | Through 14a Kelvin typed every Swift file. From 14b Claude writes each verified phase onto a branch of the iOS project and Kelvin reviews and merges it; Claude never commits to `main` or pushes (D-93). |
| **Pace** | No deadline. Understanding beats speed. |

---

## 2. How the iOS app gets built on this Windows laptop

### 2.1 The big picture

Apple's official tool, Xcode, only runs on macOS. **xtool** is an open-source replacement that runs on Linux. It builds iOS apps with Swift Package Manager (SwiftPM), signs them with your Apple ID and installs them on your phone over USB. On this laptop it runs inside **WSL** (Windows Subsystem for Linux), which is a real Ubuntu system living inside Windows.

```
 WINDOWS                                 WSL 2: Ubuntu 26.04.1 LTS (user: wilch)
 ┌────────────────────────────┐          ┌───────────────────────────────────────────┐
 │ VS Code + WSL extension    │ ──────▶  │ ~/ClassPing   (a SwiftPM package)         │
 │   (you type code here)     │          │ Swift 6.4     (the compiler)              │
 │                            │          │ xtool 1.21.0  (build, sign, install)      │
 │ "iOS Dev (xtool)" shortcut │          │   uses the iOS SDK it pulled out of       │
 │   (starts everything)      │          │   Xcode_27.1_Release_Candidate.xip        │
 │                            │          │                                           │
 │ usbipd-win 5.3.0           │ ──USB──▶ │ usbmuxd (patched): talks to the iPhone    │
 └─────────────▲──────────────┘          └───────────────────────────────────────────┘
               │ USB cable through the HP USB-C dock
        ┌──────┴───────┐
        │ iPhone       │  iOS 27.2
        └──────────────┘
```

### 2.2 Every part and what it does

| Part | What it does | On this laptop |
|---|---|---|
| **WSL 2 + Ubuntu** | A Linux system inside Windows. All the iOS tools run here. | Ubuntu 26.04.1 LTS, Linux user `wilch`. |
| **Swift 6.4** | The Swift compiler and SwiftPM. | Installed with **swiftly 1.2.0**. Swift 6.4 was the first release with an Ubuntu 26.04 build, and swiftly 1.1.x can't install on 26.04. It lives in `~/.local/share/swiftly/bin`. |
| **xtool 1.21.0** | Does Xcode's job: builds, signs with your Apple ID, installs and launches on the phone. | `/usr/local/bin/xtool`. Project settings are in `xtool.yml` (bundle ID `space.classping.ios`). |
| **iOS SDK** | Apple's frameworks (SwiftUI, UserNotifications and so on) that your code compiles against. | `xtool setup` extracted it from `~/Xcode_27.1_Release_Candidate.xip`. |
| **Free Apple ID** | Signs the app so the iPhone agrees to run it. | Comes with limits, see 2.5. |
| **usbipd-win 5.3.0** | Passes the iPhone's USB connection from Windows into WSL. | It finds the phone by Apple's USB vendor ID, `05ac`. Sharing a USB port (`bind`) is remembered. Attaching isn't, so it happens every session. |
| **usbmuxd (patched)** | The Linux service that talks to iPhones over USB. | The stock version fails over usbipd with `opTimeout`. A patched build at `/usr/local/sbin/usbmuxd` is switched on by `/etc/systemd/system/usbmuxd.service.d/no-zlp.conf`. See 2.6. |
| **VS Code + WSL extension** | Where you write code. Its terminal runs inside Ubuntu. | Autocomplete and error underlines come from SourceKit-LSP, wired up by `.bsp/xtool.json`. |
| **"iOS Dev (xtool)" shortcut** | Starts a whole session in one click. | On the desktop. It runs `C:\Users\kelvi\Scripts\Start-iOSDev.ps1`. |

### 2.3 Your daily routine

1. **Double-click "iOS Dev (xtool)"** on the desktop. It opens `~/ClassPing` in VS Code (connected to WSL), waits for Ubuntu to start, finds the iPhone and attaches it to Ubuntu. Leave its window open while you work.
2. **Plug in the iPhone and unlock it.** The first time you use a new USB port, Windows asks for admin permission once. That's `usbipd bind` sharing the port.
3. **In the VS Code terminal**, which is already inside Ubuntu in `~/ClassPing`, run:
   ```bash
   xtool dev
   ```
   That builds the app, signs it, installs it and opens it on your phone.
4. **Change code, save, run `xtool dev` again.** To check that it compiles without touching the phone, run `xtool dev build`.
5. **Done for the day?** Close the shortcut's window.

### 2.4 The iOS project right now

```
/home/wilch/ClassPing
├── Package.swift        swift-tools-version 6.0, platforms .iOS(.v18) and .macOS(.v14)
├── xtool.yml            bundleID: space.classping.ios
├── .bsp/xtool.json      lets VS Code understand the project
└── Sources/ClassPing/
    ├── ClassPingApp.swift     app entry point (still the template version: it only shows RootView)
    ├── RootView.swift         the Week and Tasks tabs
    ├── Models.swift           Course and Assignment (typed by Kelvin)
    ├── Store.swift            the @Observable store plus sample data
    ├── WeekView.swift         placeholder
    └── AssignmentsView.swift  placeholder
```

This follows an earlier, smaller plan: the Claude doc [ClassPing iOS: Main Pages Plan](https://claude.ai/code/artifact/cbc45025-ac92-498f-9db1-5497f0e4da1e), 10 milestones covering the seven iOS design screens. As of 2026-10-13, Milestone 1 is done and Milestone 2 is half done: the models and store exist, but `ClassPingApp.swift` doesn't create the store yet and the Tasks tab is still a placeholder. **The project isn't a git repository yet.**

### 2.5 Limits you can't code around

| Limit | Why | What we do instead |
|---|---|---|
| No push notifications | Apple's push service needs a paid developer account. | Local notifications that the phone schedules itself (`UNUserNotificationCenter`). |
| No App Groups or Associated Domains | Paid-account features. | No home-screen widget that reads the app's data, and no universal links. |
| The app stops opening after 7 days | Free-account signing expires. | Plug in the phone and run `xtool dev` again. |
| Only installs on your own devices | Free accounts can't distribute apps. | Fine for now. |
| No Simulator, no live `#Preview` | Both need macOS. `#Preview` compiles, but nothing can display it. | Test on the phone. |
| SwiftData (`@Model`) fails to build | Tested on this laptop on 2026-10-11. `@Observable` works. | Codable structs saved as JSON files. |
| Swift 6 strict concurrency | `swift-tools-version: 6.0` turns on data-race checking. | Shared state lives on `@MainActor`. Read the compiler's message, it explains the problem. |
| About 64 pending local notifications | iOS keeps only the 64 soonest. | Schedule the nearest ones, and top up whenever the app opens. |

### 2.6 When something breaks

| Symptom | Likely cause | Fix |
|---|---|---|
| `Error: noDevice` | The phone isn't attached to Ubuntu. | Run the shortcut, or in Windows run `usbipd list` and then `usbipd attach --wsl --busid <BUSID>`. Unlock the phone and tap Trust if it asks. |
| `Error: opTimeout` | The stock usbmuxd is running instead of the patched one. | In Ubuntu, run `systemctl cat usbmuxd`. Its last section should be `no-zlp.conf`, setting `ExecStart=/usr/local/sbin/usbmuxd`. Then run `sudo systemctl restart usbmuxd`. |
| The app's icon is there but it won't open | Signing expired (7 days), or Developer Mode is off. | Run `xtool dev` again. Check Settings > Privacy & Security > Developer Mode. |
| `sending 'self' risks causing data races` | Swift 6 isolation rules. | Copy what you need into a local `let` before switching to the main actor, or mark the type `@MainActor`. |
| Errors mentioning `@Model` | SwiftData doesn't work with xtool here. | Use Codable + JSON. |

**Why usbmuxd is patched:** a USB transfer whose size is an exact multiple of 512 bytes needs an extra zero-length packet to mark its end. usbipd loses that packet, so two messages merge into one oversized message that the phone rejects, and the connection times out. The patched build (from `/usr/local/src/usbmuxd`, commit `3ded00c`) never sends a transfer whose size is a multiple of 512 bytes, so that packet is never needed. To undo the patch:

```bash
sudo rm -r /etc/systemd/system/usbmuxd.service.d && sudo systemctl daemon-reload && sudo systemctl restart usbmuxd
```

---

## 3. Rules for every Claude session (binding)

### 3.1 Sources of truth, in this order

1. The web app's code and tests in this folder: `app/`, `components/`, `lib/` (including the `lib/*.test.ts` files) and `tests/journeys/`.
2. The written rules: `AGENTS.md`, `docs/PRODUCT_RULES.md`, `docs/ARCHITECTURE.md`, `docs/SCHEMA.md`, `PRD.md`, `SPEC.md` and `choices.md`.
3. The iOS screen designs (screens 01 to 07): `C:\Users\kelvi\Downloads\ClassPing functional breakdown-handoff\classping-functional-breakdown\project\ClassPing Screens.dc.html`
4. Kelvin. When the sources disagree or say nothing, ask him. Don't invent features.

### 3.2 Who writes the code (changed 2026-10-22, D-93)

- **Phases 0 to 14a:** Kelvin typed every file from the guides.
- **From 14b on, Claude writes the code into `/home/wilch/ClassPing`, but only on a branch.** `docs/ios/tools/apply-phase.sh <guide>` checks his tree is clean and on `main`, makes `ios/<guide name>`, lays the guide's `### 4.N` blocks and its copied test files over his tree, runs his `scripts/test-logic.sh` and `scripts/test-store.sh`, and commits on that branch. Kelvin reviews the diff, does the phone steps and merges into `main` himself.
- **Never commit to `main`, never push** (the repo has a GitHub remote), never rewrite his history. If his tree isn't clean or isn't on `main`, stop and ask.
- Guides are change notes now (D-93): goal, what maps from the web, the files and why, phone steps, done when. No "New Swift concepts" section, no three-concept cap, no 3 to 8 file limit. The comment rules in 4.3.1 still apply to every file.
- When something fails on his side, point at the line and fix it on the branch, with a new commit.
- Never run `xtool dev` yourself, because it installs onto his phone. `xtool dev build` is fine, but only in a throwaway project in `/tmp` (see 4.3).
- Don't change the toolchain (usbmuxd, usbipd, swiftly, xtool) without asking. It took real effort to get working.

### 3.3 Don't touch the web app

- This folder is a live repository with uncommitted work in progress, so check `git status` first. Pushing `main` deploys to Vercel. **Everything except this file and `docs/ios/` is read-only for iOS work.** Don't commit or push unless Kelvin asks.
- Follow `AGENTS.md`: never print, copy or commit secrets, and don't open `.env.local`.
- The iOS app may contain only the public values the browser already gets: the Supabase URL and its anon/publishable key, and the Clerk publishable key. Kelvin supplies them when sync starts. **Never** a Supabase service-role key, OpenAI key, `CRON_SECRET`, VAPID private key, Clerk secret key or email API key.

### 3.4 The web app's product rules apply to the iOS app

`docs/PRODUCT_RULES.md` is binding here too. These are the rules that shape the Swift code most:

- **Days run Monday to Sunday as 0 to 6.** Convert to Apple's numbering (1 = Sunday) in exactly one helper.
- **Times of day are minutes from midnight.** 600 means 10:00 AM.
- **A deadline is local wall-clock time, never an instant.** `due` is a date like 2026-07-09 or nil, and `dueTime` is a time like 14:30 or nil. No date means Inbox; a date with no time means all-day. Never turn all-day into 23:59. Take the exact string formats from `lib/supabase/map.ts`.
- **Undated work is never sorted in with dated work.**
- **Deleting is soft:** set `deletedAt`, keep the item for 30 days, and let it be restored.
- **Local-first:** every change is saved on the phone before any network call. Never show "Synced" before the server confirms.
- **Use the web app's words on screen:** Today, Planner, Tasks, Notes, Grades, Classes, Inbox, and "Complete" / "Completed".
- **Quiet hours** silence the app's nudges, but a pre-class alarm still rings.

### 3.5 Swift code rules

- Swift 6 language mode: keep `swift-tools-version: 6.0`. Shared app state is one `@MainActor @Observable` store, split across files with `extension Store`.
- Never name a type `Class` (it's a Swift keyword) or `Task` (that's Swift's concurrency type). The models are `Course` and `Assignment`.
- **No `do`/`try`/`catch` blocks and no `break` inside loops** (Kelvin's rule). Use `try?` with `guard` or `if let`. Instead of breaking out of a loop, use `first(where:)`, `filter`, `contains(where:)` or a `while` condition.
- Save data with Codable + JSON files in the app's Documents folder. No SwiftData.
- Model fields mirror the Supabase columns (`start_min` becomes `startMin`, `class_id` becomes `courseID`), so adding sync later is a mapping, not a migration.
- Pure logic ported from `lib/*.ts` goes in `Sources/ClassPing/Logic/` and imports only `Foundation`. That keeps it testable on Linux (4.3.2).
- The deployment target is iOS 18; Kelvin's phone runs 27.2. If a feature needs a newer API, propose raising the target as a decision. Don't do it quietly.

---

## 4. The task

> **Map the current web app's architecture, structure and design. Then recreate it in Swift, grouped into efficient phases, until the iOS app is fully coded.** Every Swift file starts with a header that says where it's created and what it does, and every code block has comments that explain its purpose and how it works. Kelvin codes each file himself. There's no time limit.

**Map features, not code blocks.** A one-to-one port of every code block would copy things a phone app must never contain, like server routes that hold secret keys, SQL migrations, cron jobs and the service worker. So first sort every part of the web app into one of five buckets:

| Bucket | Meaning | First-pass examples (confirm in Step 1) |
|---|---|---|
| **Port** | Pure logic, rewritten in Swift with the same behavior and the same test cases. | `lib/time.ts`, `lib/deadline.ts`, `lib/task-view.ts`, `lib/class-meetings.ts`, `lib/planning.ts`, `lib/reminders.ts`, `lib/exam-prep.ts`, `lib/gpa.ts`, `lib/study.ts`, `lib/streak.ts`, `lib/xp.ts`, `lib/pet.ts`, `lib/trophies.ts`, `lib/boss.ts`, `lib/quotes.ts`, `lib/notes.ts`, `lib/highlight.ts`, `lib/backup.ts`, `lib/recovery.ts`, `lib/ics-import.ts`, `lib/ics-reconcile.ts`, `lib/csv-import.ts`, `lib/paste-schedule.ts`, `lib/merge.ts` |
| **Rebuild** | Screens remade in SwiftUI from the web pages' behavior and the designs. | `app/home` (Today), `app/week` (Planner), `app/tasks/**`, `app/classes` (Notes), `app/class/**`, `app/grades/**`, `app/settings`, `app/prompt` (post-class prompt), `app/lock`, and the `components/` they use |
| **Connect** | Stays on the server, and the app calls it. | The Supabase tables (after Clerk sign-in), plus `app/api/parse/task`, `app/api/import/schedule`, `app/api/notes/tidy`, `app/api/export/**`, `app/api/avatar`, `app/api/account` and `app/api/feedback` |
| **Replace** | Browser or desktop plumbing that has a native iOS equivalent. | `localStorage` becomes JSON files. The 30-second in-app reminder loop and web push (`public/sw.js`, `lib/push.ts`, `app/api/push/subscribe`) become scheduled local notifications. `app/manifest.ts` and the icons become the app icon. Install prompts aren't needed. |
| **Skip** | Not part of the phone app. | Marketing pages in `app/(site)/**`, `app/admin`, `app/dev/**`, `app/api/cron/**`, email (`lib/email*`), `app/api/webhooks/**`, legacy Pro code, SEO files, `src-tauri/`, `scripts/`, `tools/`, and both migrations folders (read them, don't port them) |

### 4.1 Step 1: Map the web app

**Deliverable:** `docs/ios/WEB-TO-IOS-MAP.md`

**Read first:** `AGENTS.md`, `PRD.md`, `SPEC.md`, `choices.md`, `docs/ARCHITECTURE.md`, `docs/SCHEMA.md` and `docs/PRODUCT_RULES.md`. Then read `lib/supabase/columns.ts` and `lib/supabase/map.ts` (the data contract), `lib/store.tsx` (the heart of the app, about 138 KB: state, cache, sync and reminders), `components/TabBar.tsx` and `components/Sidebar.tsx` (navigation), `app/globals.css` (design tokens) and the iOS designs file.

**The map must contain:**

1. **Architecture:** one diagram of the web app's layers (Clerk, Next.js, localStorage, Supabase, Neon, service worker, crons, Tauri) and what each becomes on iOS.
2. **Navigation:** every route and the iOS screen it becomes, plus how you reach it. The phone web app has four tabs (Today, Notes, Planner, Tasks) with an Add button in the middle. Grades and Settings are reached from Today.
3. **Data:** each Supabase table (`profiles`, `classes`, `tasks`, `grades`, `notes`, `task_plans`, `study_sessions`, `game_state`) mapped to a Swift model, field by field: column, TypeScript type, Swift type, notes. Flag what today's models are missing. `Course` has 10 of the 23 client-owned `classes` columns, `Assignment` has 8 of the 20 `tasks` columns, and `Assignment.due` must become optional so Inbox work can exist.
4. **Logic:** every file in `lib/` with its bucket, the Swift file it becomes, and its test file. Each file appears exactly once.
5. **Screens and components:** every file in `app/` and `components/` with its bucket and its SwiftUI counterpart.
6. **Design:** the tokens in `app/globals.css` (five accent colors with Baby Pink as the default plus Ocean, dark mode, card radius, spacing, type) mapped to a `Theme.swift`, and the shared components mapped to SwiftUI views or view modifiers.
7. **Decisions for Kelvin.** Ask before Step 2, and don't decide these alone:
   - **Tabs.** The iOS designs show Week + Tasks, but the web app now uses Today, Notes, Planner and Tasks with an Add button. Recommend matching the web app.
   - **iOS target.** Stay on iOS 18, or raise it if a feature needs it (for example, rich-text notes)?
   - **Order of the big features:** notes editor, grades, study timer, pet and gamification, imports, sign-in and sync.
   - **Anything to leave out for now.**

### 4.2 Step 2: Plan the phases

**Deliverable:** `docs/ios/PHASES.md`

**How to shape the phases:**

- **Follow the dependencies:** models and logic, then screens, then notifications, with sign-in and sync last. Sync needs every model to be final, and it's the riskiest part.
- **Every phase ends with something Kelvin can run and tap on his phone.**
- **Each phase introduces at most two or three new Swift concepts,** listed at the top of the phase.
- **Aim for 3 to 8 files per phase,** and split anything bigger.
- **Build on Kelvin's existing files.** Extend `Models.swift` and `Store.swift` rather than making him retype them.
- **Absorb the Main Pages Plan.** For each phase, say which old milestone it replaces.

**Starting draft** (rework it after the map):

| Phase | Builds | Main web sources |
|---|---|---|
| 0 | Housekeeping: `git init` in `~/ClassPing`, the folder layout, finishing the store wiring left over from Milestone 2 | |
| 1 | Complete data models, JSON save and load, a sample planner | `docs/SCHEMA.md`, `lib/supabase/map.ts`, `lib/godmode.ts` |
| 2 | Time and deadline logic, with Linux tests | `lib/time.ts`, `lib/deadline.ts` |
| 3 | App shell: tabs, Add menu, theme tokens, dark mode | `components/TabBar.tsx`, `components/AddMenu.tsx`, `app/globals.css` |
| 4 | Tasks: list, filters, detail, add and edit, complete, soft delete | `app/tasks/**`, `lib/task-view.ts`, `components/TaskFilterBar.tsx`, `components/QuickAddTask.tsx` |
| 5 | Classes and Planner: class form, meetings, week grid | `app/class/**`, `components/ClassForm.tsx`, `components/MeetingFields.tsx`, `app/week`, `lib/class-meetings.ts` |
| 6 | Today: next class, priorities, planned work | `app/home`, `lib/planning.ts`, `components/QuoteBanner.tsx`, `components/FinalsCountdown.tsx` |
| 7 | Reminders: local notifications, quiet hours, snooze, the exam ladder, the post-class prompt | `lib/reminders.ts`, `lib/exam-prep.ts`, `components/TaskReminders.tsx`, `components/QuietHours.tsx`, `app/prompt` |
| 8 | Notes: class and quick notes, reader, editor, search, links to tasks | `app/classes`, `lib/notes.ts`, `lib/highlight.ts`, `components/NoteEditor.tsx`, `components/NoteReader.tsx` |
| 9 | Grades, GPA and grade scales | `app/grades/**`, `lib/gpa.ts`, `components/GradeFields.tsx`, `components/GradeScaleEditor.tsx` |
| 10 | Study timer, focus blocks, streaks | `components/StudyTimer.tsx`, `lib/study.ts`, `lib/streak.ts` |
| 11 | Progress and pet: XP, levels, trophies, the weekly boss | `lib/xp.ts`, `lib/pet.ts`, `lib/trophies.ts`, `lib/boss.ts`, `components/ClassPet.tsx` |
| 12 | Settings, backup and restore, Recently Deleted, term setup | `app/settings`, `lib/backup.ts`, `lib/recovery.ts`, `components/RestoreSheet.tsx`, `components/TermSetupSheet.tsx` |
| 13 | Imports: calendar feeds (ICS), CSV, pasted schedules | `lib/ics-import.ts`, `lib/ics-reconcile.ts`, `lib/feeds.ts`, `lib/csv-import.ts`, `lib/paste-schedule.ts`, `components/ImportCalendar.tsx` |
| 14 | Sign-in and sync: Clerk + Supabase, three-way merge, the column contract, Realtime | `lib/store.tsx` (its sync parts), `lib/sync.ts`, `lib/merge.ts`, `lib/supabase/*` |
| 15 | The server's AI features, called through its API routes: quick-add parsing, schedule upload, note tidy | `app/api/parse/task`, `app/api/import/schedule`, `app/api/notes/tidy` |
| 16 | Polish: accessibility, haptics, app icon, empty states, the five test planners | `docs/PRODUCT_RULES.md` |

**Unknowns to test in the throwaway project before planning around them** (none of these has been tried with xtool yet):

- Images and other resources in the package, for the pet art and the app icon.
- The Clerk iOS SDK and supabase-swift as package dependencies.
- Whether the API routes accept a Clerk session token sent from an app, given `lib/request-security.ts`. If they don't, the fix is a web change, and that needs Kelvin's go-ahead.

**"Fully coded" means:**

- Every Port, Rebuild, Connect and Replace row in the map is built and checked on the phone.
- Every ported logic file passes Swift versions of the web app's own test cases.
- The five test planners in `docs/PRODUCT_RULES.md` behave correctly. "Long offline return" only applies once sync exists.
- The only things left are those the free Apple ID blocks, and `PHASES.md` lists them.

### 4.3 Step 3: Deliver each phase

**Deliverable:** one file per phase, `docs/ios/phase-NN-short-name.md`

Each phase file contains, in this order:

1. **Goal:** one sentence, plus what Kelvin will see on his phone at the end.
2. **New Swift concepts:** each one explained in two or three sentences with a tiny example.
3. **What it maps from the web app:** file paths, and how the Swift version differs and why.
4. **Files, in the order to type them.** For each file: its full path, whether it's new, replaces a file or adds to one, and then the **complete file**. When a phase changes an existing file, show the whole updated file and mark the touched blocks with `// NEW in Phase N` or `// CHANGED in Phase N`. That way Kelvin can see exactly what to type, and nothing ends up in the wrong place.
5. **Run it:** the exact commands, and what to tap on the phone.
6. **Done when:** a checklist of things he can see or test.
7. **If it breaks:** the two or three most likely mistakes and how to spot them.

#### 4.3.1 How every Swift file must look

**Header** (at the top of every file):

- The full path, starting from `~/ClassPing`
- The phase
- The web file or files it ports
- A summary of one to three sentences

**Comments:**

- A `///` doc comment on every type, every group of properties and every function, saying what it's for.
- A `//` comment above each block inside a function, saying what the block does and why.
- The first time a Swift concept appears, explain it. After that, keep it short.
- When the web app does the same thing, name it, for example: "In `lib/deadline.ts` this is `isOverdue`."
- Keep comments true. When the code changes, the comment changes too.

**Example** (this code compiled with xtool on this laptop):

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/TimeHelpers.swift
//  Phase:   2 (time and deadline logic)
//  Ports:   lib/time.ts (minutes-from-midnight helpers)
//
//  Summary: Converts between the "minutes from midnight" numbers ClassPing stores
//           (600 = 10:00 AM) and the Date values that SwiftUI's time pickers need.
//

import Foundation

/// Turns a time picked in a DatePicker into minutes from midnight (10:00 AM -> 600),
/// the format the Course model and Supabase use.
func minutes(from date: Date) -> Int {
    // Pull just the hour and minute out of the full date and time.
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    // `?? 0` means: use 0 if a part is missing, so the math can't crash.
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}
```

#### 4.3.2 Check the code before Kelvin sees it

Keep the latest verified code in this repo, so every session can rebuild it:

- `docs/ios/reference/Sources/ClassPing/` holds every Swift file delivered so far, in the same folders as Kelvin's project. Before the first phase, seed it with a copy of Kelvin's current files, once they build.
- `docs/ios/reference/Tests/Logic/` holds the Swift Testing versions of the web app's `lib/*.test.ts` cases.
- `docs/ios/tools/` holds the two scripts below. Save them there (with LF line endings) the first time you need them.

For each phase, write its new and changed files into the reference folder, run both checks, and fix things until both are clean. Only then does the code go into the phase file for Kelvin.

**Check 1: build (every phase).** Save as `docs/ios/tools/build-check.sh`:

```bash
#!/usr/bin/env bash
# build-check.sh: compiles the reference iOS code in a throwaway xtool project.
# It never touches ~/ClassPing. Pass a different folder as $1 to test other code.
REF="${1:-/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Sources/ClassPing}"
cd /tmp && rm -rf CPProbe && xtool new CPProbe --skip-setup > /dev/null 2>&1 && cd CPProbe || { echo "PROBE_SETUP_FAILED"; exit 1; }
sed -i 's/.iOS(.v17)/.iOS(.v18)/' Package.swift
rm -f Sources/CPProbe/*.swift
cp -r "$REF"/. Sources/CPProbe/
out=$(xtool dev build 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
echo "$out" | grep -E "error:|warning:" | sort -u
if echo "$out" | grep -q -E "Build complete|Wrote to"; then echo "BUILD_OK"; else echo "BUILD_FAILED"; fi
cd /tmp && rm -rf CPProbe
```

Run it from Windows:

```powershell
wsl -d Ubuntu -- bash -l /mnt/c/Users/kelvi/Desktop/classping/docs/ios/tools/build-check.sh
```

The bar is `BUILD_OK` with no `error:` or `warning:` lines. It compiles in a throwaway project in `/tmp` and never touches `~/ClassPing`. (`--skip-setup` skips xtool's setup prompts.)

**Check 2: logic tests (every Port).** Save as `docs/ios/tools/logic-test.sh`:

```bash
#!/usr/bin/env bash
# logic-test.sh: runs the Swift ports of the web app's lib/*.test.ts cases on Linux.
# Copies the Foundation-only Logic/ files and their tests into a throwaway package.
IOS=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference
SRC="${1:-$IOS/Sources/ClassPing/Logic}"
TESTS="${2:-$IOS/Tests/Logic}"
cd /tmp && rm -rf CPLogic && mkdir CPLogic && cd CPLogic || { echo "SETUP_FAILED"; exit 1; }
swift package init --type library --name CPLogic > /dev/null 2>&1
rm -f Sources/CPLogic/*.swift Tests/CPLogicTests/*.swift
cp -r "$SRC"/. Sources/CPLogic/
cp -r "$TESTS"/. Tests/CPLogicTests/
swift test 2>&1 | grep -E "error:|passed|failed" | tail -25
cd /tmp && rm -rf CPLogic
```

Run it from Windows:

```powershell
wsl -d Ubuntu -- bash -l /mnt/c/Users/kelvi/Desktop/classping/docs/ios/tools/logic-test.sh
```

The tests use Swift Testing: `import Testing`, `@testable import CPLogic`, `@Test func ...` and `#expect(...)`. Kelvin doesn't have to type the tests. They prove that the Swift port behaves the way the web app does.

Both scripts were tested on this laptop on 2026-10-13. The build check compiled a target that has a subfolder, and the logic tests ran in about 10 seconds. Swift Testing in this WSL handles `DateFormatter`, `Calendar` and time-zone math (a DST-change case passed).

**Running other WSL commands from Windows** (for sessions using Desktop Commander):

- The easiest way is to save a script under `docs/ios/tools/` and run it with `wsl -d Ubuntu -- bash -l /mnt/c/...`. The `-l` loads the PATH that finds `swift`.
- For a one-off command with several lines, remember that PowerShell mangles bash quotes and `$` signs. Base64-encode the script and run:
  ```powershell
  wsl -d Ubuntu -- bash -lc "echo <base64> | base64 -d > /tmp/job.sh; bash /tmp/job.sh; rm -f /tmp/job.sh"
  ```
  Keep each command under about 30,000 characters, because the Windows limit is 32,767.
- To read Kelvin's files without running a command, open `\\wsl.localhost\Ubuntu\home\wilch\ClassPing\Sources\ClassPing\`.

### 4.4 Step 4: Keep the trail

- **`docs/ios/PROGRESS.md`:** the current phase, which files Kelvin has typed (check by reading his folder), what has been verified, and open questions. Update it at the end of every session.
- **`docs/ios/DECISIONS.md`:** one entry per decision, with the date, the decision, why, and the options that were turned down.
- **Every session starts the same way:** read this file, `PROGRESS.md` and the current phase file, then list Kelvin's `Sources/ClassPing/` folder to see where he actually is.

---

## 5. Learning aid: from the web app to Swift

| In the web app | In SwiftUI | Note |
|---|---|---|
| A React component, `function TaskRow(props)` | `struct TaskRow: View` with `let` properties | Views are cheap values that SwiftUI rebuilds often. |
| `useState` | `@State private var` | A view's own memory. |
| Props and callbacks passed down | `let` properties, and `@Binding` for two-way values | `$value` passes a binding. |
| React context (the provider in `lib/store.tsx`) | An `@Observable` class, `.environment(store)` and `@Environment(Store.self)` | One store for the whole app. |
| `useEffect` | `.task { }`, `.onChange(of:)`, `.onAppear` | `.task` runs async work tied to the view's lifetime. |
| `useMemo` | A computed property | Recomputed when what it reads changes. |
| Next.js routes and `<Link>` | `TabView`, `NavigationStack`, `NavigationLink`, `.sheet` | Navigation is state, not URLs. |
| `localStorage` | A JSON file in the Documents folder | `Codable` + `JSONEncoder` and `JSONDecoder`. |
| `fetch` | `URLSession` with `async`/`await` | |
| Tailwind classes and CSS variables | View modifiers and a `Theme` with named colors | |
| Date math in `lib/time.ts` | `Calendar`, `DateComponents`, `DateFormatter` | Use `Locale(identifier: "en_US_POSIX")` for stored formats. |
| vitest `expect(x).toBe(y)` | Swift Testing `#expect(x == y)` | |
| Service worker notifications, web push | Local notifications with `UNUserNotificationCenter` | |
| `try { } catch { }` | `try?` with `guard` or `if let` | Kelvin's rule: no try/catch blocks. |
| supabase-js, Clerk for Next.js | supabase-swift, the Clerk iOS SDK | Phase 14. Test that they build with xtool first. |

---

## 6. Cheat sheet

| What | Where or how |
|---|---|
| Start a session | Desktop shortcut **iOS Dev (xtool)** |
| Build, install and launch | `xtool dev` (inside `~/ClassPing`) |
| Build only | `xtool dev build` |
| Open the project by hand | `code --remote wsl+Ubuntu /home/wilch/ClassPing` |
| Attach the phone by hand (Windows) | `usbipd list`, then `usbipd attach --wsl --busid <BUSID>` |
| The iOS project, from Windows | `\\wsl.localhost\Ubuntu\home\wilch\ClassPing` |
| Startup script | `C:\Users\kelvi\Scripts\Start-iOSDev.ps1` |
| iOS designs | `C:\Users\kelvi\Downloads\ClassPing functional breakdown-handoff\classping-functional-breakdown\project\ClassPing Screens.dc.html` |
| Earlier plan (10 milestones) | [ClassPing iOS: Main Pages Plan](https://claude.ai/code/artifact/cbc45025-ac92-498f-9db1-5497f0e4da1e) |
| xtool documentation | https://xtool.sh/documentation/xtool/ |
| Swift basics | [A Swift Tour](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/guidedtour/) |
| SwiftUI basics | [Apple's SwiftUI tutorials](https://developer.apple.com/tutorials/swiftui) (skip the Xcode-only steps) |
| Swift Testing | https://developer.apple.com/documentation/testing |
