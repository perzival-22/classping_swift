//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/ClassMeetings.swift
//  Phase:   5a (the new tab bar and the week)
//  Ports:   lib/class-meetings.ts (ClassMeeting, validMeeting,
//           validAdditionalMeetings, classMeetings, expandClassMeetings,
//           isUnscheduled, meetingKey, meetingError, meetingSummary)
//
//  Summary: A class can meet more than once a week at different times, like
//           Mon/Wed lectures plus a Friday lab. This file turns a class into
//           its list of meetings, checks that meetings make sense, and flattens
//           many classes into the slots the week grid draws. Foundation only,
//           so the Linux test runner can compile it on its own.
//

import Foundation

/// One time a class meets: which days, from when to when, and optionally
/// where and under what name ("Lab"). `ClassMeeting` in lib/class-meetings.ts.
/// It's saved inside the class (`additional_meetings`), so its fields keep the
/// web's names, `start` and `end`, in minutes from midnight.
// CHANGED in Phase 5a: moved here from Models.swift, so the tests can see it
struct ClassMeeting: Identifiable, Codable, Hashable {
    var id = UUID()
    var days: [Int]            // 0 = Monday ... 6 = Sunday
    var start: Int             // minutes from midnight
    var end: Int
    var room: String? = nil
    var label: String? = nil   // e.g. "Lab"
}

/// The id of a class's main meeting. The web calls it `"primary"`; ids here
/// are UUIDs, so the main meeting gets the all-zero UUID instead. `UUID()`
/// never makes that value (a random UUID always has its version bits set),
/// so it can't clash with a real extra meeting.
let primaryMeetingID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

/// The most meeting times one class can have, main meeting included.
/// `MAX_MEETINGS` in lib/class-meetings.ts.
let maxMeetings = 20

/// Short day names, Monday first, so `dayLabels[0]` is "Mon".
/// `DAY_LABELS` in lib/class-meetings.ts.
let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

/// Anything with a timetable: a main meeting stored on the thing itself, plus
/// a list of extra meetings. `Course` signs up in Models.swift. A protocol
/// keeps this file free of the Course model, the same trick as `Dated` in
/// Phase 2, so the tests can use a tiny stand-in instead of a whole Course.
/// `{ get }` means "readable": the protocol only ever reads these.
protocol Schedulable {
    var id: UUID { get }
    var days: [Int] { get }
    var startMin: Int { get }
    var endMin: Int { get }
    var room: String? { get }
    var additionalMeetings: [ClassMeeting] { get }
}

// MARK: - Checking meetings

/// Is this meeting usable? `validMeeting` in lib/class-meetings.ts.
/// (The web also checks the id's characters; a UUID is always well-formed.)
func validMeeting(_ m: ClassMeeting) -> Bool {
    // Days: one to seven of them, no repeats, each one a real weekday.
    // `Set(...)` drops duplicates, so a shorter set means a repeat.
    let daysOK = !m.days.isEmpty && m.days.count <= 7
        && Set(m.days).count == m.days.count
        && m.days.allSatisfy { (0...6).contains($0) }
    // Times: inside one day, and ending after they start.
    let timesOK = m.start >= 0 && m.end < 1440 && m.end > m.start
    // Text: the same caps as the web's inputs. Nothing (nil) always passes.
    let textOK = (m.room?.count ?? 0) <= 200 && (m.label?.count ?? 0) <= 80
    return daysOK && timesOK && textOK
}

/// Are these extra meetings safe to keep? `validAdditionalMeetings`.
/// Fewer than 20 (the main meeting is the 20th), each valid, none pretending
/// to be the main meeting, and no id used twice.
func validAdditionalMeetings(_ meetings: [ClassMeeting]) -> Bool {
    meetings.count < maxMeetings
        && meetings.allSatisfy { validMeeting($0) }
        && !meetings.contains(where: { $0.id == primaryMeetingID })
        && Set(meetings.map(\.id)).count == meetings.count
}

/// What the class form shows under the meetings when Save can't go ahead,
/// or nil when all is well. `meetingError` in lib/class-meetings.ts.
func meetingError(_ meetings: [ClassMeeting]) -> String? {
    // A class needs at least one meeting, and at most 20.
    if meetings.isEmpty || meetings.count > maxMeetings {
        return "Add between 1 and \(maxMeetings) meeting times."
    }
    // The first broken meeting, by position. `firstIndex(where:)` stops at
    // the first match, which is how the web's loop returns early.
    if let bad = meetings.firstIndex(where: { !validMeeting($0) }) {
        return "Meeting \(bad + 1): choose at least one day and an end time after the start time."
    }
    // Two meetings with one id would confuse every screen that tells them apart.
    if Set(meetings.map(\.id)).count != meetings.count {
        return "Meeting identifiers must be unique."
    }
    return nil
}

// MARK: - From classes to meetings

/// Every time a class meets: the main meeting first, then the extra ones.
/// `classMeetings` in lib/class-meetings.ts. The main meeting is built from
/// the class's own days, times and room. Extra meetings that fail the checks
/// are left out entirely, the way the web treats a damaged list.
/// `<C: Schedulable>` makes this generic (Phase 4a): it works for a Course or
/// for anything else that has a timetable.
func classMeetings<C: Schedulable>(_ c: C) -> [ClassMeeting] {
    let main = ClassMeeting(id: primaryMeetingID, days: c.days,
                            start: c.startMin, end: c.endMin, room: c.room)
    let extra = validAdditionalMeetings(c.additionalMeetings) ? c.additionalMeetings : []
    return [main] + extra
}

/// One meeting of one class, ready to draw on the week: the class it belongs
/// to, side by side with when it meets. The web spreads both into one object
/// (`expandClassMeetings` keeps the class's fields and adds `meetingId`); Swift
/// keeps them as two named parts, so `slot.course.name` and
/// `slot.meeting.start` say exactly where each value comes from.
struct MeetingSlot<C: Schedulable>: Identifiable {
    let course: C
    let meeting: ClassMeeting

    /// Unique per slot, even when one class meets twice on the same day.
    var id: String { meetingKey(self) }
}

/// Every meeting of every class, flattened into one list of slots.
/// `expandClassMeetings` in lib/class-meetings.ts.
func expandClassMeetings<C: Schedulable>(_ classes: [C]) -> [MeetingSlot<C>] {
    // `flatMap` turns "a list of lists" (each class's slots) into one list.
    classes.flatMap { c in
        classMeetings(c).map { MeetingSlot(course: c, meeting: $0) }
    }
}

/// True for a class added before its timetable was known: none of its
/// meetings has a day, so it never lands on the week. `isUnscheduled`.
func isUnscheduled<C: Schedulable>(_ c: C) -> Bool {
    classMeetings(c).allSatisfy { $0.days.isEmpty }
}

/// A slot's unique key. The main meeting keeps the class's own id (old links
/// still work); an extra meeting adds its own id after a colon.
/// `meetingKey` in lib/class-meetings.ts.
func meetingKey<C: Schedulable>(_ slot: MeetingSlot<C>) -> String {
    let courseKey = slot.course.id.uuidString
    return slot.meeting.id == primaryMeetingID
        ? courseKey
        : "\(courseKey):\(slot.meeting.id.uuidString)"
}

/// One line describing when a class meets, for lists:
/// "Mon/Wed 09:00–10:15 · Room 4; Lab: Fri 14:00–16:00".
/// `meetingSummary` in lib/class-meetings.ts.
func meetingSummary<C: Schedulable>(_ c: C) -> String {
    if isUnscheduled(c) { return "No set schedule yet" }
    let parts = classMeetings(c).map { m in
        // Like the web, an empty label or room counts as none.
        let label = nonEmpty(m.label).map { "\($0): " } ?? ""
        let room = nonEmpty(m.room).map { " · \($0)" } ?? ""
        // A day outside 0...6 would crash `dayLabels[d]`, so it shows as "?".
        let days = m.days.map { dayLabels.indices.contains($0) ? dayLabels[$0] : "?" }
        return "\(label)\(days.joined(separator: "/")) \(clock24(m.start))–\(clock24(m.end))\(room)"
    }
    return parts.joined(separator: "; ")
}

/// 545 -> "09:05", the 24-hour form `meetingSummary` uses.
private func clock24(_ mins: Int) -> String {
    String(format: "%02d:%02d", mins / 60, mins % 60)
}

/// The text, or nil when it's missing or empty.
private func nonEmpty(_ s: String?) -> String? {
    guard let s, !s.isEmpty else { return nil }
    return s
}
