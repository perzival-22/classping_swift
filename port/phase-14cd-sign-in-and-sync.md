---
title: "Phase 14cd: Sign-in and sync"
date: 2026-10-22
---
# Phase 14cd: Sign-in and sync

A change note (D-93). Branch `ios/phase-14cd-sign-in-and-sync`, stacked on
`ios/phase-14b-row-mapping` (it contains 14b, so merging 14cd brings both).
Built in steps (D-100): step 1 the SDKs, step 2 sign-in and the sync engine.
Realtime is not in yet (see section 2). **Not merged, and not for merging
until the phone steps in section 5 have worked.**

**Verification (2026-10-22):** GitHub checks on step 2 (`fcd664f`, run
39775758716): logic **633/633** (+10, `SyncPlanTests`), store **154/154**
(+10, `SyncStoreTests`, a fake server, no network) on Swift 6.4.1; iOS build
green on Xcode 26.6. Your xtool built step 2 too (a throwaway clone of the
branch on the laptop, 95 s, only the SDKs' own deprecation warnings). Sign-in,
Supabase and the first sync have **not run on a phone**.

## 1. Goal

On the Profile tab, an Account card replaces "Coming to this tab": Continue
with Google, then "Signed in as …" with the sync row (14a's words: Saved on
this device, Syncing, Synced just now, Offline, an error in plain words),
Sync now and Sign out. The first time your account syncs on this phone, a
review sheet shows what would happen, table by table, and nothing is sent or
changed until you've backed up and tapped Sync now (D-90, D-97). After that
every change saves on the phone first and reaches classping.space a moment
later; coming back to the app brings in what changed on the web.

## 2. What it maps from the web

- `lib/supabase/client.ts` to `Sync/SupabaseTransport.swift`: supabase-swift
  2.55.4 with Clerk's session token as `accessToken`, as the web's
  `createClient(url, anonKey, { accessToken })`. The eight selects, `upsert`
  (profiles and game_state keyed by `user_id`), `delete().in("id", …)`, and
  the `{ user_id, tz }` write.
- The web's Clerk setup to `Sync/Account.swift`: ClerkKit 1.6.1 (vendored,
  D-96), `Clerk.configure` at launch, Google through
  `clerk.auth.signInWithOAuth(provider: .google)` in a secure browser sheet,
  `getToken` (with `skipCache` after a 401), sign out. No URL type in
  Info.plist: the browser sheet catches `space.classping.ios://callback` by
  itself. **The redirect is pinned (D-102):** ClerkKit's default reads the
  installed bundle ID, which xtool turns into `XTL-<team>.space.classping.ios`,
  so `Account.configure()` passes the callback explicitly.
- `lib/store.tsx`'s hydrate and flush to `Store+Sync.swift`, and their
  bookkeeping to `Logic/SyncPlan.swift`: the snapshot (one file per account,
  `Documents/sync-<user>.json`), fingerprints (14a's `hashRow` of the row's
  JSON with sorted keys), the merge (14a), a note both sides changed kept as
  a "Conflicted copy" (`conflictTitle`), the profile rule (yours wins only if
  you changed it since the last sync), progress always from the server, the
  flush order (profile, classes, tasks, grades, notes, planned days, study
  sessions, progress), deletes for what left this phone, and the snapshot
  learning each confirmed step so a failure halfway loses nothing.
- The two sync effects of `lib/store.tsx` to `Sync/SyncEngine.swift`: pull
  when you sign in, push 800 ms after a change, a quiet token refresh up to
  three times (`AUTH_RETRY_LIMIT`), 14a's retry waits. **Different from the
  web (D-101):** the first sync waits for the review and your tap; the pull
  runs one table at a time; Realtime is left for later, and the app pulls each
  time it comes back to the screen instead; "Not now" signs out.

## 3. Read these closely

1. `Store+Sync.swift`, `applyPull`: the whole merge. On a first sync there's
   no snapshot, so an item both sides have that differs is a clash and the
   **web's version wins** (a note keeps the phone's as a copy). The review
   counts these as "differ".
2. `Store+Sync.swift`, `push`: deletes on the server are only ever ids the
   snapshot has and this phone no longer does. A first sync starts with no
   snapshot, so it can't delete anything on the web.
3. `SyncEngine.confirmFirstSync`: it pulls again before merging, because the
   planner may have changed while you read the review.
4. `Account.signInWithGoogle` and `SupabaseTransport`: `Task { … }.result`
   turns a thrown error into a `Result`, which keeps the error's words for
   the sync row without a do/catch block.

## 4. Files

New: `Sources/ClassPing/Logic/SyncPlan.swift`, `Sources/ClassPing/Store+Sync.swift`,
`Sources/ClassPing/Sync/SyncConfig.swift`, `Sources/ClassPing/Sync/Account.swift`,
`Sources/ClassPing/Sync/SupabaseTransport.swift`, `Sources/ClassPing/Sync/SyncEngine.swift`,
`Sources/ClassPing/Screens/Profile/AccountCard.swift` (the card and the review sheet),
`Tests/Logic/SyncPlanTests.swift`, `Tests/Store/SyncStoreTests.swift`, `Vendor/clerk-ios/` (step 1).
Changed: `Package.swift` (step 1), `Sources/ClassPing/ClassPingApp.swift` (Clerk at launch,
`SyncDriver`), `Sources/ClassPing/Screens/ProfileView.swift` (the Account card),
`scripts/test-store.sh` (copies `Store+Sync`).

## 5. Run it

Before the phone: in the Clerk Dashboard, Native applications, turn the
Native API on if it isn't, and add `space.classping.ios://callback` under
"Allowlist for mobile SSO redirect". Without it Google sends you back to the
web instead of the app.

```bash
cd ~/ClassPing
git fetch origin
git switch ios/phase-14cd-sign-in-and-sync
scripts/test-logic.sh     # expect 633 passing
scripts/test-store.sh     # expect 154 passing
xtool dev
```

On the phone, in this order:

1. Profile tab, the Account card at the bottom: tap **Continue with Google**.
   Google's sheet opens; pick your account. You come back to the app and the
   card says "Signed in as …". If a message shows under the button instead,
   send it to me word for word.
2. The **Your first sync** sheet opens by itself. Read the counts (classes,
   tasks and so on: how many go to the web, come from the web, differ). Do
   they match what you'd expect? Screenshot it for me.
3. Tap **Later**, then back up: Profile, Your data, **Back up my data**, and
   export a backup from Settings on classping.space.
4. Back on the card, **Review first sync**, turn on **I've backed up both**,
   tap **Sync now**. The card should end on "Synced just now".
5. Open classping.space and refresh: anything you made only on the phone is
   there now, and the web's own things are on the phone.
6. Change a task on the phone. Within a couple of seconds the card says
   "Synced". Refresh the web: the change is there.
7. Change something on the web, then switch away from the app and back. The
   change shows on the phone.
8. Turn on airplane mode, change something, turn it off and come back to the
   app: it should end on "Synced" without you doing anything.
9. Also owed from earlier (D-95): 13b steps 5 and 6, 13b+ steps 5 to 10.

Pushed to `ios/phase-14cd-sign-in-and-sync` by Claude; nothing merged into
`main` or installed by the agent.

## 6. Done when

- [ ] Signed in with Google on the phone.
- [ ] The review's counts make sense, and the first sync ends on "Synced".
- [ ] A change on either side shows up on the other (steps 6 and 7).
- [ ] Offline changes go through once back online (step 8).
- [ ] Merged into `main`.

## 7. If it breaks

- "Couldn't sign in: The current redirect url ... does not match an
  authorized redirect URI": the redirect Clerk got isn't in the dashboard's
  allowlist. The first build sent `XTL-V6P7S9UKM7.space.classping.ios://callback`
  (xtool's bundle ID, 2026-10-22 08:28); D-102 pins it to
  `space.classping.ios://callback`, so pull and reinstall. If the message
  still names an `XTL-` URL, the phone is running the old build.
- Google opens but never comes back to the app, or lands on classping.space:
  the callback isn't allowlisted. Check the dashboard entry reads exactly
  `space.classping.ios://callback`, and send me the URL you land on.
- "Your session expired. Sign in again to keep syncing." straight after
  signing in: Supabase isn't accepting Clerk's token from the phone. Send the
  exact words; the fix is on the Supabase or Clerk side, not in your data.
- "This account isn't allowed to save that.": row-level security refused a
  write. Nothing was lost on the phone; send the words.
- The review says lots "go to the web" and "come from the web" for things
  you have on both: an item made separately on the phone and on the web has
  two different ids, so it's two items and you'd end up with both. Items the
  phone got from a web backup (11b+c) keep the web's ids and match. Tap
  "Not now" if that's not what you want; it signs out and changes nothing.
