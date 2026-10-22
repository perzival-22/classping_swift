---
title: "Phase 14e: Signed-in server calls"
date: 2026-10-22
---
# Phase 14e: Signed-in server calls

A change note (D-93). Branch `ios/phase-14e-server-calls`, from `main` at
`0ae74d2` (14b and 14cd merged). **Not merged.**

**Verification (2026-10-22):** GitHub checks on `b06486a` (run 39785351631, and run 39784743368 on the
first push): logic **682/682** (+49: `FeedReconcileTests`, `WebCallsTests`,
against `WebValues14e.swift`), store **166/166** (+12, `FeedStoreTests`) on
Swift 6.4.1; iOS build green on Xcode 26.6. No xtool build (the laptop wasn't
used). Nothing has run on a phone, and the phone's Bearer token has never
reached the web's routes yet (D-103).

## 1. Goal

Everything on the Profile tab that needs the web's server, now that you can
sign in:

- **Live calendar feeds.** In Import from your school, signed in: paste your
  school's calendar feed link (Brightspace, Canvas, Moodle, Google), **Save
  feed and preview**, tick what you want, **Apply**. The feed stays on your
  profile (it syncs, so the web has it too) with **Refresh** and ×. A refresh
  shows what changed before anything is written, grouped as on the web: New,
  Changed at school, Changed in both places, Cancelled by the school, No
  longer in the feed, Matched. Anything that could lose your work starts
  unticked.
- **Your photo.** A photo set on the web now shows on the phone (it showed
  as initials). A new photo picked on the phone uploads to the web's storage.
- **Email.** A card under Reminders with the web's five switches.
- **Rate ClassPing.** The web's star card, above Account.
- **Delete account.** At the bottom of the Account card, two taps, as on the web.

## 2. What it maps from the web

- `lib/ics-reconcile.ts` → `Logic/FeedReconcile.swift`, whole: fingerprints,
  the seven actions, the field changes in words, identity matching for items
  imported before ids, `planWrites`, `entryKey`. It works on plain rows
  (`FeedLocalRow`), so its rules run in the Linux logic tests, and its
  fingerprints are written exactly as `JSON.stringify` writes them, so a class
  imported on the phone refreshes quietly on the web and back (D-104).
- `lib/feeds.ts` and `previewFeed` / `applyFeedWrites` in `lib/store.tsx` →
  `Store+Feeds.swift`. New deadlines go to the Inbox, as on the web; a removed
  class takes its work with it under one stamp, like deleting a class.
- `components/FeedRefresh.tsx` → `Screens/Import/FeedRefreshView.swift`; the
  feed half of `ImportCalendar.tsx` → `ImportView.swift` (signed in only;
  signed out, the panel is as before, with a line where the web shows its old
  Pro offer).
- The `fetch("/api/…")` calls → `Sync/WebAPI.swift`, with Clerk's session
  token as `Authorization: Bearer`, which the web already accepts (D-103). No
  web change. What the answers mean → `Logic/WebCalls.swift`.
- `uploadAvatar` → `ProfileCard.swift`, plus a version on the address
  (D-105); drawing https photos → `Components/AvatarLoader.swift`.
- The Email switches → `Screens/Profile/EmailPrefsCard.swift` (D-107);
  `ReviewCard.tsx` → `Screens/Profile/ReviewCard.swift`; delete account →
  `AccountCard.swift` and `eraseAfterAccountDeleted` in `Store+Sync.swift`
  (D-106).

Two web bugs found on the way are in PROGRESS.md's "Web fixes for after the
app" (12 and 13): calendar times in UTC read as local times, and a new photo
keeping the old address.

## 3. Read these closely

1. `reconcileKind` in `Logic/FeedReconcile.swift`: the whole refresh in one
   function. Note what happens to something you deleted (matched, never
   brought back) and to an item with no fingerprint (treated as edited).
2. `ownedClassJSON` and `jsJSONString`: why the fingerprint text is written
   by hand rather than with `JSONEncoder`.
3. `applyFeedWrites` in `Store+Feeds.swift`: which fields a refresh may
   change, and the one stamp for removals.
4. `WebAPI.send` / `WebReply.tokenRefused`: the retry with a fresh token, and
   why redirects are refused.
5. `ProfileCard.use`: upload first, fall back to the photo inside the profile.

## 4. Files

New: `Logic/FeedReconcile.swift`, `Logic/WebCalls.swift`, `Store+Feeds.swift`,
`Sync/WebAPI.swift`, `Components/AvatarLoader.swift`,
`Screens/Import/FeedRefreshView.swift`, `Screens/Profile/EmailPrefsCard.swift`,
`Screens/Profile/ReviewCard.swift`; tests `Tests/Logic/FeedReconcileTests.swift`,
`Tests/Logic/WebCallsTests.swift`, `Tests/Logic/WebValues14e.swift` (written by
`port/tools/gen-webvalues-14e.ts` from the web's own code),
`Tests/Store/FeedStoreTests.swift`.

Changed: `Screens/Import/ImportView.swift`, `Screens/Profile/AccountCard.swift`,
`Screens/Profile/ProfileCard.swift`, `Screens/Profile/ProfileBanner.swift`,
`Screens/ProfileView.swift`, `Store+Sync.swift`, `scripts/test-store.sh`
(`Store+Feeds` added to its list).

## 5. Run it

```bash
cd ~/ClassPing
git fetch origin
git switch ios/phase-14e-server-calls
scripts/test-logic.sh     # expect 682 passing
scripts/test-store.sh     # expect 166 passing
xtool dev
```

On the phone, signed in, in this order:

1. **Your photo:** Profile tab. If you have a photo on classping.space, the
   banner and the tab-bar badge show it now, not initials.
2. **Email:** the EMAIL card under Reminders loads your five switches. Turn
   one off, refresh Settings on the web: it's off there too. Turn it back on.
3. **A feed:** in Brightspace, Calendar, Subscribe (the "all courses" feed),
   copy the link. Profile, Import from your school, paste it, **Save feed
   and preview**. The preview opens: how many changes, then the groups.
   Screenshot it for me before you apply.
4. Untick anything you don't want, **Apply**. "Added N items" shows; the
   classes are on your week and the deadlines in Tasks (Inbox). The feed is
   listed under YOUR FEEDS, "Refreshed today".
5. **Refresh** it straight away: "Already up to date".
6. Open classping.space, Settings: the same feed is in its list, and the
   web's Refresh there also says nothing changed. (That's the fingerprints
   agreeing.) Check one deadline's time against Brightspace: if it's hours
   off, tell me which (web fix 12).
7. **A new photo:** tap your photo, pick another. "Saving your photo…", then
   it shows. Refresh the web: the new photo is there.
8. **Rate ClassPing:** pick stars, write a line, **Send review**. "Thank
   you!" shows, and the email reaches your inbox.
9. **Delete account, but don't:** tap **Delete account** at the bottom of the
   Account card, read the warning, tap **Keep my account**. Never tap
   **Delete forever** on your real account.
10. Signed out (only if you want to check it): the import panel goes back to
    the file buttons with a line about signing in, and the Email and Rate
    cards are gone.

If anything shows a message instead, send it to me word for word.

When they pass:

```bash
git switch main
git merge --ff-only origin/ios/phase-14e-server-calls
git push origin main
```

Pushed to `ios/phase-14e-server-calls` by Claude; nothing merged into `main`
or installed by the agent.

## 6. Done when

- [ ] Your web photo shows on the phone, and a new one reaches the web.
- [ ] The Email switches load and a change shows on the web.
- [ ] A Brightspace feed previews, applies, and refreshes as "Already up to date" on both apps.
- [ ] A review arrives in your inbox.
- [ ] Merged into `main`.

## 7. If it breaks

- "Your session expired. Sign out and back in, then try again." on every
  server call: the web isn't taking the phone's token (D-103). Send me the
  words and which card; the fix is on the web or Clerk side.
- "Couldn't import that calendar." or the server's own sentence ("That link
  didn't return a calendar feed."): the server couldn't read the link. Try
  the link in Safari; a Brightspace link needs the "Subscribe" one, not the
  calendar page.
- The preview lists everything as "Changed in both places" after a refresh
  on the other app: the fingerprints disagree. Screenshot one row.
- The Email card stays on "Couldn't load your email settings.": the server's
  email database isn't reachable from that route (`prefs_unavailable`).
- Your photo stays as initials: the photo's address isn't https, or the
  download failed; check the web shows it.
