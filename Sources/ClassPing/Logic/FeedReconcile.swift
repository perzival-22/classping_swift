//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/FeedReconcile.swift
//  Phase:   14e (signed-in server calls)
//  Ports:   lib/ics-reconcile.ts (classFingerprint, taskFingerprint,
//           reconcileFeed, planWrites, entryKey and their helpers)
//
//  Summary: Refreshing a saved calendar feed without wrecking what you've
//           done to the classes and deadlines it brought in. For each item it
//           answers "what changed, and who changed it?" (new, changed at
//           school, changed in both places, cancelled, gone from the feed),
//           and only what you tick is written. Foundation only: the store
//           turns its classes and assignments into the plain rows below
//           (Store+Feeds.swift), so these rules run in the Linux tests.
//

import Foundation

// MARK: - What the feed owns

/// The class fields a calendar feed may change on a refresh. Everything else
/// (color, short name, reminders, credits, instructor, notes, term) is yours,
/// and a refresh never touches it. `OwnedClassFields`.
struct OwnedClass: Equatable, Sendable {
    var name: String
    var days: [Int]
    var start: Int
    var end: Int
    var room: String? = nil
    /// Extra meeting times. A feed never sends any; a class you gave extra
    /// times to still counts them, so its fingerprint shows it was edited.
    var additionalMeetings: [ClassMeeting] = []
}

/// The assignment fields a feed owns. Not `done`, not its class, not its
/// notes or reminders: a refresh must never un-tick something you handed in
/// because the deadline is still published. `OwnedTaskFields`.
struct OwnedTask: Equatable, Sendable {
    var title: String
    var due: String?
    var dueTime: String?
    var kind: String
}

extension ImportedClass {
    /// The part of an incoming class the feed has an opinion about.
    var owned: OwnedClass {
        OwnedClass(name: name, days: days, start: start, end: end, room: room,
                   additionalMeetings: additionalMeetings)
    }
}

extension ImportedTask {
    /// The part of an incoming assignment the feed has an opinion about.
    var owned: OwnedTask {
        OwnedTask(title: title, due: due, dueTime: dueTime, kind: kind)
    }
}

// MARK: - Fingerprints

/// Text written the way JavaScript's `JSON.stringify` writes a string:
/// quotes around it, `"` and `\` escaped, the short escapes for backspace,
/// form feed, newline, return and tab, `\u00xx` (lower case) for the other
/// control characters, and everything else as it is (no `\/`, no escaped
/// accents). A Swift `JSONEncoder` escapes "/" and differs in small ways, so
/// the fingerprint text is written by hand.
func jsJSONString(_ text: String) -> String {
    var out = "\""
    // `unicodeScalars` walks the text one code point at a time.
    for scalar in text.unicodeScalars {
        switch scalar {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\u{08}": out += "\\b"
        case "\u{0C}": out += "\\f"
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        default:
            if scalar.value < 0x20 {
                // `String(_:radix:)` writes the number in hex; pad to four.
                let hex = String(scalar.value, radix: 16)
                out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
    }
    return out + "\""
}

/// `null`, or the text as a JSON string.
private func jsJSONOptional(_ text: String?) -> String {
    text.map(jsJSONString) ?? "null"
}

/// A list of whole numbers as JSON: `[0,2]`.
private func jsJSONInts(_ numbers: [Int]) -> String {
    "[" + numbers.map(String.init).joined(separator: ",") + "]"
}

/// The JSON the web fingerprints for a class, key for key in the web's
/// order: `JSON.stringify(ownedClass(c))`. Days sorted; an empty room left
/// out (`room || undefined`); extra meetings only when there are any.
func ownedClassJSON(_ c: OwnedClass) -> String {
    var json = "{\"name\":" + jsJSONString(c.name)
    json += ",\"days\":" + jsJSONInts(c.days.sorted())
    json += ",\"start\":\(c.start),\"end\":\(c.end)"
    if let room = c.room, !room.isEmpty {
        json += ",\"room\":" + jsJSONString(room)
    }
    // A feed never sends meetings and the web never stores a fingerprint
    // with them, so this only has to make an edited class look edited.
    if !c.additionalMeetings.isEmpty {
        let meetings = c.additionalMeetings.map { m in
            var one = "{\"days\":" + jsJSONInts(m.days) + ",\"start\":\(m.start),\"end\":\(m.end)"
            if let room = m.room { one += ",\"room\":" + jsJSONString(room) }
            return one + "}"
        }
        json += ",\"additionalMeetings\":[" + meetings.joined(separator: ",") + "]"
    }
    return json + "}"
}

/// The JSON the web fingerprints for an assignment: `JSON.stringify(ownedTask(t))`,
/// with null for no date or no time.
func ownedTaskJSON(_ t: OwnedTask) -> String {
    "{\"title\":" + jsJSONString(t.title)
        + ",\"due\":" + jsJSONOptional(t.due)
        + ",\"dueTime\":" + jsJSONOptional(t.dueTime)
        + ",\"kind\":" + jsJSONString(t.kind) + "}"
}

/// A class's fingerprint: 14a's `hashRow` of its owned fields. Stored on the
/// row as `sourceHash` when it arrives and worked out again on each refresh:
/// equal means you haven't edited it since. The same text the web hashes, so
/// a class imported on the phone refreshes quietly on the web and back.
func classFingerprint(_ c: OwnedClass) -> String {
    hashRow(ownedClassJSON(c))
}

/// An assignment's fingerprint, the same way. `taskFingerprint`.
func taskFingerprint(_ t: OwnedTask) -> String {
    hashRow(ownedTaskJSON(t))
}

// MARK: - Decisions

/// What a refresh would do with one item. `FeedAction`.
enum FeedAction: String, CaseIterable, Sendable {
    /// In the feed, and nothing here matches it.
    case add
    /// Matches one imported before ids were recorded: claim it, don't copy it.
    case adopt
    /// Changed at school, untouched by you since it arrived. Safe to apply.
    case update
    /// Changed at school AND edited by you. You decide.
    case conflict
    /// The same in both places. Nothing to do.
    case unchanged
    /// The feed says it's cancelled.
    case withdrawn
    /// Came from this feed but isn't in it any more. It may only have
    /// scrolled out of the weeks your school publishes.
    case missing

    /// Ticked when the preview opens: new things and safe updates are, since
    /// that's what a refresh is for; anything that could lose your work or
    /// delete something you still need isn't. `defaultChecked`.
    var startsTicked: Bool {
        self == .add || self == .adopt || self == .update
    }
}

/// One field the feed wants to change, ready to show: "Days: Mon Wed → Tue Thu".
struct FieldChange: Equatable, Sendable {
    var field: String
    var label: String
    var from: String
    var to: String
}

/// One row of the preview. `FeedEntry<T>`: `incoming` is what the feed now
/// says (nil for cancelled and missing), `localID` the item here it concerns.
struct FeedEntry<Incoming: Equatable & Sendable>: Equatable, Sendable {
    var action: FeedAction
    /// The calendar's id for the event. Empty only for an item a feed never named.
    var uid: String
    var title: String
    var localID: String? = nil
    var incoming: Incoming? = nil
    var changes: [FieldChange] = []
    /// Ticked when the preview opens.
    var checked: Bool

    /// A key for this row that stays the same if the list is re-sorted:
    /// action, id, local id and title. `entryKey`.
    var key: String {
        "\(action.rawValue):\(uid):\(localID ?? ""):\(title)"
    }
}

/// What a refresh of one feed would do. `FeedPlan`.
struct FeedPlan: Equatable, Sendable {
    var feedID: String
    var classes: [FeedEntry<ImportedClass>]
    var tasks: [FeedEntry<ImportedTask>]
    /// How many of each action, across both lists, for the summary line.
    var totals: [FeedAction: Int]

    /// The rows that need you: everything but "unchanged".
    var actionableKeys: [String] {
        (classes.filter { $0.action != .unchanged }.map(\.key))
            + (tasks.filter { $0.action != .unchanged }.map(\.key))
    }

    /// The keys ticked when the preview opens.
    var defaultPicks: Set<String> {
        Set(classes.filter(\.checked).map(\.key) + tasks.filter(\.checked).map(\.key))
    }
}

// MARK: - Showing a change

/// Short day names, Monday first like the app's days.
private let FEED_DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

/// "Mon Wed", or "-" for no days. `fmtDays`.
func feedDaysText(_ days: [Int]) -> String {
    guard !days.isEmpty else { return "-" }
    return days.map { FEED_DAY_NAMES.indices.contains($0) ? FEED_DAY_NAMES[$0] : String($0) }
        .joined(separator: " ")
}

/// Minutes from midnight as "09:05". `fmtMins`.
func feedTimeText(_ mins: Int) -> String {
    let h = String(mins / 60)
    let m = String(mins % 60)
    return String(repeating: "0", count: max(0, 2 - h.count)) + h + ":"
        + String(repeating: "0", count: max(0, 2 - m.count)) + m
}

/// The room, or nil when it's empty, as `room || undefined` reads it.
private func roomOrNil(_ room: String?) -> String? {
    guard let room, !room.isEmpty else { return nil }
    return room
}

/// What the feed changed on a class, in words. `classChanges`.
func classChanges(_ before: OwnedClass, _ after: OwnedClass) -> [FieldChange] {
    var out: [FieldChange] = []
    if before.name != after.name {
        out.append(FieldChange(field: "name", label: "Name", from: before.name, to: after.name))
    }
    let a = before.days.sorted()
    let b = after.days.sorted()
    if a != b {
        out.append(FieldChange(field: "days", label: "Days", from: feedDaysText(a), to: feedDaysText(b)))
    }
    if before.start != after.start || before.end != after.end {
        // "–" is an en dash, as the web writes a range.
        out.append(FieldChange(field: "time", label: "Time",
                               from: "\(feedTimeText(before.start))–\(feedTimeText(before.end))",
                               to: "\(feedTimeText(after.start))–\(feedTimeText(after.end))"))
    }
    if (roomOrNil(before.room) ?? "") != (roomOrNil(after.room) ?? "") {
        out.append(FieldChange(field: "room", label: "Room",
                               from: roomOrNil(before.room) ?? "-", to: roomOrNil(after.room) ?? "-"))
    }
    return out
}

/// "2026-10-01 23:59", "2026-10-01" or "No deadline".
private func dueText(_ t: OwnedTask) -> String {
    guard let due = t.due, !due.isEmpty else { return "No deadline" }
    if let time = t.dueTime, !time.isEmpty { return "\(due) \(time)" }
    return due
}

/// What the feed changed on an assignment, in words. `taskChanges`.
func taskChanges(_ before: OwnedTask, _ after: OwnedTask) -> [FieldChange] {
    var out: [FieldChange] = []
    if before.title != after.title {
        out.append(FieldChange(field: "title", label: "Title", from: before.title, to: after.title))
    }
    if dueText(before) != dueText(after) {
        out.append(FieldChange(field: "due", label: "Due", from: dueText(before), to: dueText(after)))
    }
    if before.kind != after.kind {
        out.append(FieldChange(field: "kind", label: "Type", from: before.kind, to: after.kind))
    }
    return out
}

// MARK: - Matching

/// A class's identity for items imported before ids were recorded: name
/// (trimmed, lower case), days and start. Two classes that agree on those are
/// the same class. `classIdentity`.
func classIdentity(_ c: OwnedClass) -> String {
    let days = c.days.map(String.init).sorted().joined(separator: ",")
    return "\(c.name.trimmed.lowercased())|\(days)|\(c.start)"
}

/// An assignment's identity: title and due day. `taskIdentity`.
func taskIdentity(_ t: OwnedTask) -> String {
    "\(t.title.trimmed.lowercased())|\(t.due ?? "")"
}

/// One class or assignment already here, as the matching needs it. The store
/// makes these from its Courses and Assignments, deleted ones included:
/// without them a refresh would bring back what you threw away.
struct FeedLocalRow<Owned: Equatable & Sendable>: Equatable, Sendable {
    /// The item's id, as the web writes it.
    var id: String
    var owned: Owned
    var sourceFeed: String? = nil
    var sourceUID: String? = nil
    var sourceHash: String? = nil
    /// In Recently Deleted.
    var deleted = false
}

/// How one kind of item is matched and compared. Classes and assignments
/// follow the same rules with different fields, so the rules are written
/// once (`reconcileKind`), with these four answers passed in.
struct FeedRules<Owned>: Sendable {
    let title: @Sendable (Owned) -> String
    let fingerprint: @Sendable (Owned) -> String
    let identity: @Sendable (Owned) -> String
    let diff: @Sendable (Owned, Owned) -> [FieldChange]
}

/// The class rules.
let CLASS_FEED_RULES = FeedRules<OwnedClass>(
    title: { $0.name }, fingerprint: classFingerprint, identity: classIdentity, diff: classChanges)

/// The assignment rules.
let TASK_FEED_RULES = FeedRules<OwnedTask>(
    title: { $0.title }, fingerprint: taskFingerprint, identity: taskIdentity, diff: taskChanges)

/// The matching itself, for one kind of item. `reconcileKind`.
func reconcileKind<Owned: Equatable & Sendable, Incoming: Equatable & Sendable>(
    feedID: String,
    cancelled: Set<String>,
    incoming: [Incoming],
    uidOf: (Incoming) -> String?,
    ownedOf: (Incoming) -> Owned,
    local: [FeedLocalRow<Owned>],
    rules: FeedRules<Owned>
) -> [FeedEntry<Incoming>] {
    // This feed's own rows, by the calendar id they carry.
    let fromThisFeed = local.filter { $0.sourceFeed == feedID }
    var byUID: [String: FeedLocalRow<Owned>] = [:]
    for row in fromThisFeed {
        if let uid = row.sourceUID, !uid.isEmpty { byUID[uid] = row }
    }

    // The fallback index: this feed's rows without an id, and rows with no
    // feed at all (what an import before ids looks like). A row another feed
    // owns is left alone: two feeds publishing the same lecture is yours to sort out.
    var adoptable: [String: FeedLocalRow<Owned>] = [:]
    for row in local {
        if let uid = row.sourceUID, !uid.isEmpty, row.sourceFeed == feedID { continue }
        if let feed = row.sourceFeed, !feed.isEmpty, feed != feedID { continue }
        let key = rules.identity(row.owned)
        if adoptable[key] == nil { adoptable[key] = row }
    }

    var out: [FeedEntry<Incoming>] = []
    var seenLocalIDs: Set<String> = []
    var seenUIDs: Set<String> = []

    for item in incoming {
        let owned = ownedOf(item)
        let uid = uidOf(item) ?? ""
        if !uid.isEmpty { seenUIDs.insert(uid) }

        let matched = uid.isEmpty ? nil : byUID[uid]
        // `??` tries the id match first, then the fallback.
        guard let found = matched ?? adoptable[rules.identity(owned)] else {
            out.append(FeedEntry(action: .add, uid: uid, title: rules.title(owned),
                                 incoming: item, checked: FeedAction.add.startsTicked))
            continue
        }
        seenLocalIDs.insert(found.id)

        // You deleted it and the school still publishes it. That's no reason
        // to bring it back: matched (so it's never added again), never shown,
        // never written.
        if found.deleted {
            out.append(FeedEntry(action: .unchanged, uid: uid, title: rules.title(owned),
                                 localID: found.id, checked: false))
            continue
        }

        let changes = rules.diff(found.owned, owned)
        if changes.isEmpty {
            // Identical. Found only by its fields, it's still worth claiming:
            // stamping the id on now stops the NEXT refresh from copying it.
            let action: FeedAction = matched == nil ? .adopt : .unchanged
            out.append(FeedEntry(action: action, uid: uid, title: rules.title(owned),
                                 localID: found.id, incoming: item, checked: action.startsTicked))
            continue
        }

        // Did you touch it since it arrived? No fingerprint means it can't be
        // known, and that's treated as "you did": asking costs one tap,
        // guessing wrong costs your edit.
        let untouched = found.sourceHash.map { $0 == rules.fingerprint(found.owned) } ?? false
        let action: FeedAction = untouched ? .update : .conflict
        out.append(FeedEntry(action: action, uid: uid, title: rules.title(owned),
                             localID: found.id, incoming: item, changes: changes,
                             checked: action.startsTicked))
    }

    // This feed's rows that the fetch didn't mention. `where` skips the ones
    // already matched, already deleted, or whose id did show up.
    for row in fromThisFeed where !seenLocalIDs.contains(row.id) && !row.deleted
        && !seenUIDs.contains(row.sourceUID ?? "") {
        let uid = row.sourceUID ?? ""
        let action: FeedAction = !uid.isEmpty && cancelled.contains(uid) ? .withdrawn : .missing
        out.append(FeedEntry(action: action, uid: uid, title: rules.title(row.owned),
                             localID: row.id, checked: action.startsTicked))
    }
    return out
}

/// What a refresh of one feed would do, without doing any of it.
/// `reconcileFeed`. `classes` and `tasks` are everything here, deleted
/// items included.
func reconcileFeed(feedID: String, found: ImportResult,
                   classes: [FeedLocalRow<OwnedClass>],
                   tasks: [FeedLocalRow<OwnedTask>]) -> FeedPlan {
    let cancelled = Set(found.cancelled)
    let classEntries = reconcileKind(feedID: feedID, cancelled: cancelled, incoming: found.classes,
                                     uidOf: \.sourceUID, ownedOf: \.owned, local: classes,
                                     rules: CLASS_FEED_RULES)
    let taskEntries = reconcileKind(feedID: feedID, cancelled: cancelled, incoming: found.tasks,
                                    uidOf: \.sourceUID, ownedOf: \.owned, local: tasks,
                                    rules: TASK_FEED_RULES)
    // Every action starts at zero, so the summary can read any of them.
    var totals = Dictionary(uniqueKeysWithValues: FeedAction.allCases.map { ($0, 0) })
    for action in classEntries.map(\.action) + taskEntries.map(\.action) {
        totals[action, default: 0] += 1
    }
    return FeedPlan(feedID: feedID, classes: classEntries, tasks: taskEntries, totals: totals)
}

// MARK: - Turning decisions into writes

/// Where a written item came from: the feed, the calendar's id for it, and
/// the fingerprint of what the feed said. Every write carries a fresh one, so
/// the next refresh can tell an untouched item from an edited one.
struct FeedStamp: Equatable, Sendable {
    var sourceFeed: String
    var sourceUID: String?
    var sourceHash: String
}

/// A class to add, with its stamp.
struct FeedClassAdd: Equatable, Sendable {
    var item: ImportedClass
    var stamp: FeedStamp
}

/// An assignment to add, with its stamp.
struct FeedTaskAdd: Equatable, Sendable {
    var item: ImportedTask
    var stamp: FeedStamp
}

/// A class to change: only the fields the feed owns, plus the stamp.
struct FeedClassUpdate: Equatable, Sendable {
    var id: String
    var name: String
    var days: [Int]
    var start: Int
    var end: Int
    var room: String?
    var stamp: FeedStamp
}

/// An assignment to change: only the fields the feed owns, plus the stamp.
/// Never `done`, never its class.
struct FeedTaskUpdate: Equatable, Sendable {
    var id: String
    var title: String
    var due: String?
    var dueTime: String?
    var kind: String
    var stamp: FeedStamp
}

/// Exactly what applying a refresh writes. `FeedWrite`.
struct FeedWrite: Equatable, Sendable {
    var addClasses: [FeedClassAdd] = []
    var addTasks: [FeedTaskAdd] = []
    var updateClasses: [FeedClassUpdate] = []
    var updateTasks: [FeedTaskUpdate] = []
    /// Classes you chose to remove because the feed dropped them. Kept apart
    /// from assignments: a class takes its work with it, and only the store knows that.
    var removeClassIDs: [String] = []
    var removeTaskIDs: [String] = []

    /// How many items it adds, changes and removes, for "Added N items".
    var count: Int {
        addClasses.count + addTasks.count + updateClasses.count + updateTasks.count
            + removeClassIDs.count + removeTaskIDs.count
    }
}

/// The plan plus your ticks, as the writes to make. `planWrites`.
func planWrites(_ plan: FeedPlan, accepted: Set<String>) -> FeedWrite {
    var write = FeedWrite()

    // `where` keeps only the rows you ticked.
    for entry in plan.classes where accepted.contains(entry.key) {
        let stamp = entry.incoming.map {
            FeedStamp(sourceFeed: plan.feedID, sourceUID: entry.uid.isEmpty ? nil : entry.uid,
                      sourceHash: classFingerprint($0.owned))
        }
        switch entry.action {
        case .add:
            if let item = entry.incoming, let stamp {
                write.addClasses.append(FeedClassAdd(item: item, stamp: stamp))
            }
        case .update, .conflict, .adopt:
            if let id = entry.localID, let item = entry.incoming, let stamp {
                write.updateClasses.append(FeedClassUpdate(id: id, name: item.name, days: item.days,
                                                           start: item.start, end: item.end,
                                                           room: item.room, stamp: stamp))
            }
        case .withdrawn, .missing:
            if let id = entry.localID { write.removeClassIDs.append(id) }
        case .unchanged:
            continue
        }
    }

    for entry in plan.tasks where accepted.contains(entry.key) {
        let stamp = entry.incoming.map {
            FeedStamp(sourceFeed: plan.feedID, sourceUID: entry.uid.isEmpty ? nil : entry.uid,
                      sourceHash: taskFingerprint($0.owned))
        }
        switch entry.action {
        case .add:
            if let item = entry.incoming, let stamp {
                write.addTasks.append(FeedTaskAdd(item: item, stamp: stamp))
            }
        case .update, .conflict, .adopt:
            if let id = entry.localID, let item = entry.incoming, let stamp {
                write.updateTasks.append(FeedTaskUpdate(id: id, title: item.title, due: item.due,
                                                        dueTime: item.dueTime, kind: item.kind,
                                                        stamp: stamp))
            }
        case .withdrawn, .missing:
            if let id = entry.localID { write.removeTaskIDs.append(id) }
        case .unchanged:
            continue
        }
    }
    return write
}
