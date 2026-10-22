//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Feeds.swift
//  Phase:   14e (signed-in server calls)
//  Ports:   lib/feeds.ts (upsertFeed, removeFeed, markSynced,
//           lastSyncedLabel), `previewFeed` and `applyFeedWrites` in
//           lib/store.tsx, and the feed half of components/ImportCalendar.tsx
//           (`addFeed`, `forgetFeed`, marking a feed refreshed)
//
//  Summary: Your saved calendar feeds and what a refresh writes. Saving a
//           link keeps it on your profile (it syncs, so the web has it too);
//           a refresh shows what changed before anything is written
//           (Logic/FeedReconcile.swift), and applying it writes what you
//           ticked in one save. Removals go to Recently Deleted, all with the
//           same stamp, so they come back together.
//

import Foundation

// MARK: - The saved list

/// Adds a feed, or updates the one with the same link (or id), keeping that
/// one's id: pasting a link twice refreshes it instead of stacking a copy.
/// A sixth feed isn't added. `upsertFeed`.
func upsertFeed(_ feeds: [SavedFeed], _ feed: SavedFeed) -> [SavedFeed] {
    guard let at = feeds.firstIndex(where: { $0.url == feed.url || $0.id == feed.id }) else {
        return feeds.count >= MAX_FEEDS ? feeds : feeds + [feed]
    }
    var next = feeds
    var merged = feed
    merged.id = next[at].id
    next[at] = merged
    return next
}

/// The list without one feed. `removeFeed`.
func removeFeed(_ feeds: [SavedFeed], id: UUID) -> [SavedFeed] {
    feeds.filter { $0.id != id }
}

/// The list with one feed marked refreshed at `at`. `markSynced`.
func markFeedSynced(_ feeds: [SavedFeed], id: UUID, at: Date) -> [SavedFeed] {
    feeds.map { feed in
        var copy = feed
        if copy.id == id { copy.lastSyncedAt = at }
        return copy
    }
}

/// "Never refreshed" / "Refreshed 3 days ago": how old a feed is. Whole days
/// since its last refresh, as the web counts them. `lastSyncedLabel`.
func lastSyncedLabel(_ feed: SavedFeed, now: Date) -> String {
    // The web stores "never" as 0, which reads back as no date at all.
    guard let last = feed.lastSyncedAt, last.timeIntervalSince1970 > 0 else { return "Never refreshed" }
    let days = Int((now.timeIntervalSince(last) / 86_400).rounded(.down))
    if days <= 0 { return "Refreshed today" }
    if days == 1 { return "Refreshed yesterday" }
    if days < 30 { return "Refreshed \(days) days ago" }
    return "Refreshed over a month ago"
}

// MARK: - Items as the matching sees them

extension Course {
    /// This class as Logic/FeedReconcile.swift compares it: the fields a feed
    /// owns, where it came from, and whether it's in Recently Deleted.
    var feedRow: FeedLocalRow<OwnedClass> {
        FeedLocalRow(id: webID(id),
                     owned: OwnedClass(name: name, days: days, start: startMin, end: endMin,
                                       room: room, additionalMeetings: additionalMeetings),
                     sourceFeed: sourceFeed, sourceUID: sourceUID, sourceHash: sourceHash,
                     deleted: deletedAt != nil)
    }
}

extension Assignment {
    /// This assignment as the matching compares it.
    var feedRow: FeedLocalRow<OwnedTask> {
        FeedLocalRow(id: webID(id),
                     owned: OwnedTask(title: title, due: due, dueTime: dueTime, kind: kind.rawValue),
                     sourceFeed: sourceFeed, sourceUID: sourceUID, sourceHash: sourceHash,
                     deleted: deletedAt != nil)
    }
}

extension Store {
    // MARK: - Saving and forgetting a feed

    /// Saves a pasted feed link, before it's read, so a feed that's slow or
    /// briefly down is still in the list to retry. A link already saved is
    /// that same feed. Gives back the feed to read, or the reason it can't
    /// be saved. `addFeed` in ImportCalendar.tsx.
    func saveFeed(url: String) -> Result<SavedFeed, FeedSaveProblem> {
        let link = url.trimmed
        if let existing = profile.importFeeds.first(where: { $0.url == link }) {
            return .success(existing)
        }
        guard isFeedURL(link) else { return .failure(.notALink) }
        guard profile.importFeeds.count < MAX_FEEDS else { return .failure(.full) }
        let feed = SavedFeed(url: link, label: feedLabelFromURL(link), lastSyncedAt: nil)
        let before = profile.importFeeds
        profile.importFeeds = upsertFeed(profile.importFeeds, feed)
        save()
        if lastSaveFailed {
            profile.importFeeds = before
            return .failure(.notSaved)
        }
        return .success(feed)
    }

    /// Takes a feed off the list. Everything it imported stays where it is.
    @discardableResult
    func forgetFeed(_ id: UUID) -> Bool {
        let before = profile.importFeeds
        profile.importFeeds = removeFeed(profile.importFeeds, id: id)
        save()
        if lastSaveFailed {
            profile.importFeeds = before
            return false
        }
        return true
    }

    // MARK: - Refreshing a feed

    /// What a refresh of `feed` would do with what the server read from it,
    /// without doing any of it. Every class and assignment goes in, deleted
    /// ones too, so a refresh never brings back something you threw away.
    /// `previewFeed`.
    func previewFeed(_ feed: SavedFeed, _ found: ImportResult) -> FeedPlan {
        reconcileFeed(feedID: webID(feed.id), found: found,
                      classes: courses.map(\.feedRow), tasks: assignments.map(\.feedRow))
    }

    /// Writes a refresh you applied, and marks the feed refreshed, in one
    /// save. New assignments go to the Inbox, as the web's
    /// `applyFeedWrites` adds them. A removed class takes its work with it,
    /// as deleting a class does, and every removal shares one stamp so
    /// Recently Deleted puts them back together. No Undo bar and no XP, as on
    /// the web: a refresh is bookkeeping. Gives back false, and changes
    /// nothing, when the save fails.
    @discardableResult
    func applyFeedWrites(_ write: FeedWrite, feed: SavedFeed, now: Date = .now) -> Bool {
        let before = document

        // New items, each with a new id and the feed's stamp.
        for add in write.addClasses {
            var course = Course(imported: add.item)
            course.sourceFeed = add.stamp.sourceFeed
            course.sourceUID = add.stamp.sourceUID
            course.sourceHash = add.stamp.sourceHash
            courses.append(course)
        }
        for add in write.addTasks {
            var task = Assignment(imported: add.item, courseID: nil)
            task.sourceFeed = add.stamp.sourceFeed
            task.sourceUID = add.stamp.sourceUID
            task.sourceHash = add.stamp.sourceHash
            assignments.append(task)
        }

        // Changes: only the fields the feed owns, plus a fresh stamp. Color,
        // reminders, done and the class an assignment is filed under stay yours.
        for change in write.updateClasses {
            guard let i = courses.firstIndex(where: { webID($0.id) == change.id }) else { continue }
            courses[i].name = change.name
            courses[i].days = change.days
            courses[i].startMin = change.start
            courses[i].endMin = change.end
            courses[i].room = change.room
            courses[i].sourceFeed = change.stamp.sourceFeed
            courses[i].sourceUID = change.stamp.sourceUID
            courses[i].sourceHash = change.stamp.sourceHash
        }
        for change in write.updateTasks {
            guard let i = assignments.firstIndex(where: { webID($0.id) == change.id }) else { continue }
            assignments[i].title = change.title
            assignments[i].due = change.due
            assignments[i].dueTime = change.dueTime
            assignments[i].kind = Assignment.Kind(rawValue: change.kind) ?? .assignment
            assignments[i].sourceFeed = change.stamp.sourceFeed
            assignments[i].sourceUID = change.stamp.sourceUID
            assignments[i].sourceHash = change.stamp.sourceHash
        }

        // Removals, all with one stamp. `Set` makes "is this one going?" quick.
        let goneCourses = Set(courses.map(\.id).filter { write.removeClassIDs.contains(webID($0)) })
        let goneTasks = Set(assignments.map(\.id).filter { write.removeTaskIDs.contains(webID($0)) })
        for i in courses.indices where goneCourses.contains(courses[i].id) && courses[i].deletedAt == nil {
            courses[i].deletedAt = now
        }
        // An assignment goes if you ticked it, or if its class went.
        for i in assignments.indices where assignments[i].deletedAt == nil
            && (goneTasks.contains(assignments[i].id) || assignments[i].courseID.map(goneCourses.contains) == true) {
            assignments[i].deletedAt = now
        }
        for i in grades.indices where grades[i].deletedAt == nil
            && grades[i].courseID.map(goneCourses.contains) == true {
            grades[i].deletedAt = now
        }
        for i in notes.indices where notes[i].deletedAt == nil
            && notes[i].courseID.map(goneCourses.contains) == true {
            notes[i].deletedAt = now
        }
        // A day plan for an assignment that went goes with it.
        if !goneCourses.isEmpty || !goneTasks.isEmpty {
            let planned = Set(assignments.filter { task in
                goneTasks.contains(task.id) || task.courseID.map(goneCourses.contains) == true
            }.map(\.id))
            taskPlans.removeAll { planned.contains($0.assignmentID) }
        }

        profile.importFeeds = markFeedSynced(profile.importFeeds, id: feed.id, at: now)
        save()
        if lastSaveFailed {
            replaceAll(with: before)
            return false
        }
        return true
    }
}

/// Why a pasted feed link wasn't saved.
enum FeedSaveProblem: Error, Equatable {
    /// It doesn't start with http:// or https://.
    case notALink
    /// Five feeds are saved already.
    case full
    /// The phone couldn't save it.
    case notSaved

    /// What the panel says.
    var message: String {
        switch self {
        case .notALink: "Paste the full link, starting with https://."
        case .full: "You can save \(MAX_FEEDS) feeds. Remove one first."
        case .notSaved: "Couldn't save on this device, so nothing was added. Try again."
        }
    }
}
