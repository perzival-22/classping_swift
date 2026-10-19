//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/PostClass.swift
//  Phase:   7c (taps and the post-class prompt)
//  Ports:   `justEndedClass` in lib/store.tsx, `nextClassToday` in
//           app/prompt/page.tsx, and the "where does this tap go?" part of
//           the notificationclick handler in public/sw.js
//
//  Summary: Three small answers the post-class prompt needs: which class just
//           ended, which class is next today, and where a tapped notification
//           should take you. Foundation only, so the Linux tests can run it.
//

import Foundation

// MARK: - Which class just ended, and what's next

/// How long after a class ends Today's banner and the prompt still count it
/// as "just ended", in minutes. The `windowMins = 30` default of
/// `justEndedClass`. (The notification itself only rings in the first 20,
/// `postClassWindow` in ReminderPlan.swift.)
let justEndedWindow = 30

/// The meeting that ended in the last half hour today, or nil when none did.
/// With back-to-back classes, the one that ended most recently wins.
/// `justEndedClass` in lib/store.tsx.
func justEnded<C: Schedulable>(_ courses: [C], now: Date,
                               window: Int = justEndedWindow) -> MeetingSlot<C>? {
    let today = dayIndex(of: now)
    let mins = minuteOfDay(now)
    // Today's meetings that have ended, but no more than `window` minutes ago.
    let ended = expandClassMeetings(courses).filter { slot in
        slot.meeting.days.contains(today)
            && slot.meeting.end <= mins
            && mins - slot.meeting.end <= window
    }
    // The latest end. `max(by:)` takes an "is this one smaller?" rule and
    // returns the biggest; on a tie it keeps the first, as the web's sort does.
    return ended.max { $0.meeting.end < $1.meeting.end }
}

/// The next meeting still to start today, or nil when the day's done. What
/// "No, I'm good" points you to. `nextClassToday` in app/prompt/page.tsx.
func nextClassToday<C: Schedulable>(_ courses: [C], now: Date) -> MeetingSlot<C>? {
    let today = dayIndex(of: now)
    let mins = minuteOfDay(now)
    // Today's meetings that haven't started yet; the earliest start wins.
    return expandClassMeetings(courses)
        .filter { $0.meeting.days.contains(today) && $0.meeting.start > mins }
        .min { $0.meeting.start < $1.meeting.start }
}

// MARK: - Where a tap goes

/// Where the app should take you, asked for by a tapped notification or by
/// Today's "Log it". The store holds one until RootView acts on it. The web
/// does the same job with URLs (`/home`, `/prompt?class=…`).
enum AppRoute: Equatable {
    /// The Today tab. Where a class alarm goes: the web opens Home for every
    /// reminder it rings itself.
    case today
    /// One task's detail, on the Tasks tab: a daily nudge or an early warning.
    case task(UUID)
    /// The post-class prompt about this class. Nil means "whichever class just
    /// ended", the web's `/prompt` with no `?class=`.
    case postClass(UUID?)
}

/// Reads what 7a attached to a notification (`userInfo`: its kind, class and
/// task) and says where a tap on it should go. Anything unreadable goes to
/// Today. `[AnyHashable: Any]` is iOS's "anything keyed by anything"
/// dictionary; `as? String` takes a value out only if it really is text.
func notificationRoute(_ info: [AnyHashable: Any]) -> AppRoute {
    // Each value arrives as text, or not at all. `flatMap` turns the text into
    // a kind or a UUID, and gives nil when it isn't one (7a stores "" for none).
    let kind = (info["kind"] as? String).flatMap { ReminderKind(rawValue: $0) }
    let course = (info["course"] as? String).flatMap { UUID(uuidString: $0) }
    let task = (info["assignment"] as? String).flatMap { UUID(uuidString: $0) }

    switch kind {
    case .postClass:
        return .postClass(course)
    case .taskNag, .taskLead:
        // `map` wraps a task id into a route; no id leaves nil, so `??` picks Today.
        return task.map { AppRoute.task($0) } ?? .today
    case .classAlarm, nil:
        return .today
    }
}
