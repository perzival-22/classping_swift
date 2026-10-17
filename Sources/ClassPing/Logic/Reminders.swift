//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Reminders.swift
//  Phase:   7a (reminders ring)
//  Ports:   lib/reminders.ts (quiet hours, snooze, lead times, the dedupe
//           keys and keepFiredKey). Its `dueReminders` became the planner in
//           Logic/ReminderPlan.swift (D-28).
//
//  Summary: The rules for when a nudge may ring and when it must not. Three
//           separate controls: quiet hours belong to your day, early warnings
//           ("lead times") belong to one task, and a snooze belongs to one
//           task right now. Foundation only, so the Linux tests can run it.
//

import Foundation

// MARK: - What can be reminded about

/// Anything ClassPing can nudge you about. It builds on `TaskListable` from
/// Phase 4b (title, class, kind, `due` and `dueTime`) and adds the reminder
/// fields. `Assignment` signs up in Models+Reminders.swift; the tests use a
/// small stand-in. The web reads these straight off `TaskItem`.
protocol Remindable: TaskListable {
    var id: UUID { get }
    var reminder: Bool { get }
    var done: Bool { get }
    var remindLeads: [Int] { get }
    var snoozedUntil: Date? { get }
}

/// The four kinds of notification. `ReminderKind` in lib/reminders.ts.
/// The raw values are the web's words. Swift won't take `class` as a case
/// name (it's a keyword), so that one is `classAlarm` with the raw value "class".
enum ReminderKind: String {
    case classAlarm = "class"
    case postClass = "post-class"
    case taskNag = "task-nag"
    case taskLead = "task-lead"
}

// MARK: - Quiet hours

/// A nightly window, in minutes from local midnight. `QuietHours` in the web.
/// `start` is inclusive and `end` exclusive, so 22:00 to 07:00 is silent at
/// 6:59 AM and audible at 7:00 AM: no minute belongs to both.
struct QuietHours: Equatable {
    var start: Int
    var end: Int
}

/// 10:00 PM to 7:00 AM, what the switch proposes the first time it goes on.
/// `DEFAULT_QUIET_HOURS`.
let defaultQuietHours = QuietHours(start: 22 * 60, end: 7 * 60)

/// The profile's two stored numbers as a usable window, or nil for "off".
/// `normalizeQuietHours`. The profile keeps `quietStart` and `quietEnd` as
/// two optionals (Phase 1), so this takes them apart instead of one object.
/// A window whose ends match is empty, which is how "off" is stored.
func normalizeQuietHours(start: Int?, end: Int?) -> QuietHours? {
    // Both numbers must exist and be real minutes of a day.
    guard let start, let end,
          (0...1439).contains(start), (0...1439).contains(end) else { return nil }
    // Equal ends are an empty window: off.
    guard start != end else { return nil }
    return QuietHours(start: start, end: end)
}

/// Is this minute of the day inside the quiet window? `inQuietHours`.
func inQuietHours(_ mins: Int, _ quiet: QuietHours?) -> Bool {
    // No window (or an empty one) is never quiet.
    guard let quiet, quiet.start != quiet.end else { return false }
    // A window like 9:00 to 11:00 sits inside one day. One like 22:00 to 7:00
    // wraps past midnight, so it's "late evening OR early morning".
    return quiet.start < quiet.end
        ? mins >= quiet.start && mins < quiet.end
        : mins >= quiet.start || mins < quiet.end
}

/// Which kinds ring through quiet hours: only the pre-class alarm. You set
/// that one yourself for that morning's class; everything else is the app's
/// idea, so it waits. `survivesQuietHours`.
func survivesQuietHours(_ kind: ReminderKind) -> Bool {
    kind == .classAlarm
}

/// May this kind ring at minute `mins` under `quiet`? `mayFire`.
func mayFire(_ kind: ReminderKind, _ mins: Int, _ quiet: QuietHours?) -> Bool {
    survivesQuietHours(kind) || !inQuietHours(mins, quiet)
}

// MARK: - Snooze

/// The four ways to put a task down, in the order the buttons show them.
/// `SNOOZE_PRESETS`. `CaseIterable` gives `SnoozePreset.allCases` for the
/// buttons, and `Identifiable` lets `ForEach` loop over them.
enum SnoozePreset: String, CaseIterable, Identifiable {
    case oneHour = "1h", threeHours = "3h", evening, tomorrow

    var id: String { rawValue }

    /// The button's words.
    var label: String {
        switch self {
        case .oneHour:    "1 hour"
        case .threeHours: "3 hours"
        case .evening:    "This evening"
        case .tomorrow:   "Tomorrow"
        }
    }
}

/// The hour "This evening" lands on. `EVENING_HOUR`.
private let eveningHour = 18

/// The hour "Tomorrow" lands on. `MORNING_HOUR`. Also the hour of the daily
/// nudge on the phone (D-27), which is why it isn't private.
let morningHour = 8

/// When a snooze ends. `snoozeUntil` in the web. The two named presets are
/// clock times, not offsets: "Tomorrow" means tomorrow morning, so snoozing
/// at 2 AM doesn't buy twenty-two hours of silence nobody asked for.
func snoozeUntil(_ preset: SnoozePreset, _ now: Date) -> Date {
    switch preset {
    case .oneHour:
        return now.addingTimeInterval(3600)
    case .threeHours:
        return now.addingTimeInterval(3 * 3600)
    case .evening:
        // 6 PM today, or tomorrow's 6 PM once today's has gone.
        let today = atMinute(Calendar.current.startOfDay(for: now), eveningHour * 60)
        return today > now ? today : atMinute(scheduleDate(now, 1), eveningHour * 60)
    case .tomorrow:
        return atMinute(scheduleDate(now, 1), morningHour * 60)
    }
}

/// True while a snooze is still running. `isSnoozed`. Nothing about a
/// snoozed task may ring.
func isSnoozed(_ snoozedUntil: Date?, _ now: Date) -> Bool {
    guard let snoozedUntil else { return false }
    return snoozedUntil > now
}

// MARK: - Early warnings (lead times)

/// The furthest ahead an early warning may be: 14 days. Beyond that it stops
/// being a reminder and becomes a second deadline. `MAX_LEAD_MINUTES`.
let maxLeadMinutes = 20_160

/// One choice in the "Warn me early" picker.
struct LeadChoice: Identifiable {
    let minutes: Int
    let label: String
    var id: Int { minutes }
}

/// The picker's choices, longest first. `LEAD_CHOICES`.
let leadChoices = [
    LeadChoice(minutes: 10_080, label: "1 week"),
    LeadChoice(minutes: 4_320, label: "3 days"),
    LeadChoice(minutes: 2_880, label: "2 days"),
]

/// The ladder an exam gets when you haven't picked: 1 week, 3 days, 2 days.
/// Finding out about an exam the night before is a real loss, so exams warn
/// early by default. `EXAM_LEAD_MINUTES`.
let examLeadMinutes = [10_080, 4_320, 2_880]

/// A stored list of leads cleaned up: positive, at most 14 days, no repeats,
/// longest first. Nil when nothing usable is left, which means "not chosen".
/// `normalizeLeads`. (The web also throws out text; an `[Int]` can't hold any.)
func normalizeLeads(_ raw: [Int]) -> [Int]? {
    // A Set drops repeats; `sorted(by: >)` puts the longest first.
    let kept = Set(raw.filter { $0 > 0 && $0 <= maxLeadMinutes })
    return kept.isEmpty ? nil : kept.sorted(by: >)
}

/// The leads actually in force: what you chose, else the exam ladder for an
/// exam, else none. Never invents leads for ordinary work. `effectiveLeads`.
func effectiveLeads<T: Remindable>(_ task: T) -> [Int] {
    if let chosen = normalizeLeads(task.remindLeads) { return chosen }
    return task.kindName == "exam" ? examLeadMinutes : []
}

/// "1 week", "3 days", "3 hours", "45 min". `leadLabel`. Uses the picker's
/// own words when the number is one of its choices.
func leadLabel(_ minutes: Int) -> String {
    if let known = leadChoices.first(where: { $0.minutes == minutes }) {
        return known.label
    }
    // Whole days, then whole hours, then plain minutes.
    if minutes % 1440 == 0 {
        let d = minutes / 1440
        return "\(d) day\(d == 1 ? "" : "s")"
    }
    if minutes % 60 == 0 {
        let h = minutes / 60
        return "\(h) hour\(h == 1 ? "" : "s")"
    }
    return "\(minutes) min"
}

// MARK: - Windows

/// The daily nudge runs from 24 hours before the deadline. `NAG_WINDOW_MS`,
/// in seconds here, because `TimeInterval` (what `Date` maths uses) is seconds.
let nagWindow: TimeInterval = 24 * 3600

/// An early warning is still worth sending up to a day late, not more.
/// `LEAD_GRACE_MS`.
let leadGrace: TimeInterval = nagWindow

// MARK: - Dedupe keys

/// The id of one early warning: `task:<id>:lead:<minutes>@<yyyy-MM-dd>T<HHmm>`.
/// `leadKey`. The deadline is part of it, so moving a deadline re-arms its
/// warnings: a new date deserves a new heads-up.
func leadKey(_ taskID: String, _ lead: Int, _ deadline: Date) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: deadline)
    let stamp = String(format: "%04d-%02d-%02dT%02d%02d",
                       c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    return "task:\(taskID):lead:\(lead)@\(stamp)"
}

/// The id of one day's nudge for one task: `task:<id>:<yyyy-MM-dd>`. The web
/// builds the same text inline in `dueReminders`. The day in it is what lets
/// an open task nudge again tomorrow.
func nagKey(_ taskID: String, _ day: String) -> String {
    "task:\(taskID):\(day)"
}

/// Is `key` still worth remembering as "already rang"? `keepFiredKey`.
/// Class and per-day keys die with their day. An early-warning key lives as
/// long as its task, because a one-shot must stay spent.
func keepFiredKey(_ key: String, _ dayKey: String, _ liveTaskIDs: Set<String>) -> Bool {
    // Class alarms and after-class nudges: today's only.
    if key.hasPrefix("class:") || key.hasPrefix("postclass:") {
        return key.hasSuffix(":\(dayKey)")
    }
    guard key.hasPrefix("task:") else { return false }
    let rest = String(key.dropFirst("task:".count))

    // An early warning: kept while its task exists. `range(of:)` finds where
    // ":lead:" starts, and everything before it is the task id.
    if let lead = rest.range(of: ":lead:") {
        return liveTaskIDs.contains(String(rest[..<lead.lowerBound]))
    }

    // A daily nudge: kept only today, and only for a live task. Ids never
    // contain ":", so the last ":" separates the id from the day. An old
    // `task:<id>` key with no day has no ":" left and ages out here.
    guard let sep = rest.lastIndex(of: ":") else { return false }
    return key.hasSuffix(":\(dayKey)") && liveTaskIDs.contains(String(rest[..<sep]))
}

// MARK: - Clock helper

/// The moment `mins` minutes after the start of `day`'s date, on the local
/// clock: atMinute(today, 480) is 8:00 AM today. Minutes past the end of the
/// day roll into the next one (1450 is 12:10 AM tomorrow), and negative ones
/// into the day before (-10 is 11:50 PM yesterday).
func atMinute(_ day: Date, _ mins: Int) -> Date {
    let cal = Calendar.current
    // Split into whole days and the minute within that day. Swift's `/`
    // rounds toward zero, so negative minutes need the "- 1439" to round down.
    let days = mins >= 0 ? mins / 1440 : (mins - 1439) / 1440
    let rest = mins - days * 1440
    // Step the calendar day, then build that day's clock time from its parts,
    // the same way Deadline.swift builds a deadline, so a daylight-saving
    // change can't move it by an hour.
    let base = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: day)) ?? day
    var c = cal.dateComponents([.year, .month, .day], from: base)
    c.hour = rest / 60
    c.minute = rest % 60
    return cal.date(from: c) ?? base
}
