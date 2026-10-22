---
title: "Phase 14cd: sign-in and sync, the plan"
date: 2026-10-22
---
# Phase 14cd: sign-in and sync, the plan

Written 2026-10-22 so the session that builds 14cd starts from the web's actual
sync code instead of re-reading 2,600 lines of `lib/store.tsx`. Decisions it
rests on: D-89 (logic first), D-90 and D-97 (his own account, guards first),
D-95 (one guide for sign-in and sync), D-96 (the SDKs), D-98 (pushed to a
branch, checked by CI), D-99 (14b's mapping).

## What the web does (lib/store.tsx, lines as of 2026-10-22)

- **Client** (`lib/supabase/client.ts`): `createClient(url, anonKey, {
  accessToken: () => getToken() })`. Supabase trusts Clerk's JWT (third-party
  auth); RLS scopes every row with `auth.jwt() ->> 'sub'`. No Supabase login.
- **Snapshot** (~760 to 1135): per table, a map id to `hashRow(JSON.stringify(
  xToRow(item, userId)))`, plus `profile` and `game` hashes, saved per user
  with `lastSyncedAt`. It is "what the server last told us it holds". Losing
  it only costs one conservative merge.
- **Hydrate** (~1310 to 1560): fetch all eight tables at once (`select("*")`,
  profiles and game_state `maybeSingle`). For each collection,
  `mergeWithServer(local, server.map(rowToX), snapshot, toRowJson)` (14a's
  `Merge.swift`), then the snapshot is rebuilt from the server rows. Notes:
  a conflict keeps both, the phone's copy becomes a new note titled by
  `conflictTitle`. Plans and sessions go through `normalizeTaskPlans` /
  `normalizeStudySessions`. Profile: `{ ...DEFAULT_PROFILE, ...rowToProfile,
  cleanAvatar }`; local wins only if it changed since the snapshot. Game the
  same way. Then a one-shot `tz` upsert (`pickColumns(TZ_COLUMNS)`).
- **Flush** (~1752 to 1975): 800 ms after any change, once hydrated for this
  user. Profile upsert if its hash moved; per table upsert `scopeRows(changed)`
  and **hard delete** `delete().in("id", ids)` for ids in the snapshot that
  are no longer local; game upsert; save the snapshot; status "Synced".
  Errors: an auth error refreshes the token (`skipCache`) and retries up to
  `AUTH_RETRY_LIMIT`; anything else is "offline" or "error" with
  `describeSyncError`, retried after `retryDelay(attempt)` (14a).
- **Realtime** (~1564 to 1750): one channel `store:<userId>`,
  `postgres_changes` per table filtered by user; each event is applied with
  the same three-way rule for that row, and its hash goes into the snapshot.
- **Deletes:** soft first (`deleted_at`, synced like any field). The 30-day
  clear-out drops the item locally, and the next flush hard-deletes it on the
  server because it left the local list. That is how the phone's D-75
  clear-out and the server's `purge_deleted` agree.

## What the phone gets

Swift files (new unless noted), roughly in this order:

1. `Package.swift` (changed): `supabase-swift` exact `2.55.4` (product
   `Supabase`) and `.package(path: "Vendor/clerk-ios")` (product `ClerkKit`).
   `Vendor/clerk-ios` comes from `port/tools/vendor-clerk.sh` (1.6.1, String
   Catalogs converted, D-96); commit it. CI builds with Xcode, which would take
   the original too, but the laptop's xtool needs the converted copy.
2. `Info.plist` (changed): a URL type with the scheme `space.classping.ios`,
   so Clerk's `space.classping.ios://callback` returns to the app.
3. `Sync/SyncConfig.swift`: the three public values (Clerk publishable key,
   Supabase URL, anon key). Public by design (IOS_APP.md 3.3), so they can sit
   in the source; nothing else may.
4. `Sync/Auth.swift`: `Clerk.configure` at launch, sign in with Google
   (`clerk.auth.signInWithOAuth(provider: .google)`, from Clerk's iOS custom
   flow docs), sign out, `token(skipCache:)` from
   `Clerk.shared.auth.getToken()`. ClerkKit keeps the session in the Keychain.
5. `Sync/SupabaseClient.swift`: one client with
   `SupabaseClientOptions(auth: .init(accessToken: { await Auth.token() }))`
   (supabase-swift's third-party auth option; check the exact initializer
   against 2.55.4's source before writing it).
6. `Sync/Snapshot.swift` + `Store+Sync.swift`: the snapshot (Documents,
   `sync-<userId>.json`, 14a's `snapshotToJSON`), hydrate, flush with an 800 ms
   debounce, the status (14a's `SyncStatus`), retries, the 401 rule. A row's
   hash is `hashRow` of its JSON with sorted keys (`JSONEncoder`
   `.sortedKeys`): it only has to be stable on the phone, since each device
   keeps its own snapshot.
7. `Sync/Realtime.swift`: the channel and the per-row apply.
8. Screens: an account card on the Profile tab in the web's words (sign in
   with Google, signed in as, sign out), the sync chip (14a's labels), and the
   **first-sync review** below.

Store tests can cover the snapshot, the per-row apply and the flush's diff
(which rows, which deletes) with a fake transport; nothing in the tests
touches the network.

## The guards on his own account (D-90, D-97), built in, not promised

1. **Before anything is sent**, the app asks for a backup: "Back up this
   phone" (11b+c's exporter) and a reminder to export from the web's
   Settings. The first sync can't start until he taps that he has both.
2. **The first pull writes nothing.** It runs the merge and shows the review:
   per table, how many rows the web would get (new from the phone), how many
   it would change, how many it would delete, and how many the phone would take
   from the web. Deletes on the web are listed by title.
3. **The first send is his tap.** "Send these changes" or "Not now". Only
   after the first successful send does the 800 ms automatic flush start.

Worth saying in the review: anything he typed on the phone by hand (not
restored from a web backup) has ids the web has never seen, so it shows up as
new rows, and a class entered on both sides can end up twice. The counts show
that before it happens.

## What Kelvin has to do (none of it can be done from here)

- [ ] Paste the **full** Supabase anon key (three dot-separated parts; what he
      pasted on 2026-10-22 stopped after the first).
- [ ] Clerk Dashboard > Native applications: enable the Native API if it isn't,
      and add `space.classping.ios://callback` under "Allowlist for mobile SSO
      redirect" (production needs it, per Clerk's iOS social-connection docs).
- [ ] Give the Claude GitHub app read access to `perzival-22/ClassPing`, so a
      cloud session can read `lib/` without the laptop.

## Risks

- ClerkKit only *built* under xtool (D-96); its Google flow, Keychain use and
  `getToken` have never run on his phone. If it fails on the phone, the
  fallback is `ASWebAuthenticationSession` against the web's own sign-in plus
  REST, which is a bigger change (D-96, turned down for now).
- xtool's free signing can change the bundle ID it signs with. If the callback
  doesn't return to the app, read the real ID on the phone and allowlist that.
- Realtime from supabase-swift with a third-party token: if the socket
  rejects the Clerk JWT, sync still works by pull on launch and on return to
  the foreground; Realtime can wait.
