//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Notifications.swift
//  Phase:   7a (reminders ring)
//  Ports:   lib/notifications.ts (permission, showing a notification) and the
//           bookkeeping of the reminder loop in lib/store.tsx (the fired map)
//
//  Summary: Hands the reminder plan to iOS. Each sync works out what has
//           already rung, builds the plan, and replaces iOS's list of waiting
//           notifications with it. Also asks for permission, once.
//           ClassPingApp.swift decides when to sync.
//

import Foundation
import UserNotifications

/// Whether ClassPing may show notifications, in the three states a screen
/// needs. iOS has a few more; `notificationAccess()` folds them into these.
enum NotificationAccess {
    case notAsked   // iOS hasn't asked you yet
    case allowed
    case blocked    // you said no, or turned them off in the Settings app
}

extension Store {
    /// Everything the plan is built from. When any of it changes, the app
    /// rebuilds the plan: `ReminderSync` in ClassPingApp.swift watches it.
    struct ReminderInputs: Equatable {
        var courses: [Course]
        var assignments: [Assignment]
        var postClass: Bool
        var quietStart: Int?
        var quietEnd: Int?
    }

    /// The live classes and assignments plus the two reminder settings.
    var reminderInputs: ReminderInputs {
        ReminderInputs(courses: liveCourses, assignments: liveAssignments,
                       postClass: profile.postClassNudge,
                       quietStart: profile.quietStart, quietEnd: profile.quietEnd)
    }

    // MARK: Permission

    /// What iOS currently allows, without asking anything.
    /// `async` because the answer comes from iOS's own notification service;
    /// `await` pauses here until it replies, without freezing the screen.
    func notificationAccess() async -> NotificationAccess {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notAsked
        case .denied:        return .blocked
        default:             return .allowed   // authorized, provisional, ephemeral
        }
    }

    /// Asks for permission if iOS hasn't asked yet, then says whether
    /// notifications may show. iOS draws its own Allow / Don't Allow box, and
    /// only ever once: after that it remembers the answer, and only the
    /// Settings app can change it. `ensureNotificationPermission` on the web.
    func requestNotificationAccess() async -> Bool {
        switch await notificationAccess() {
        case .allowed:
            return true
        case .blocked:
            return false
        case .notAsked:
            // `requestAuthorization` can throw; `try?` turns a failure into
            // nil, and `?? false` turns nil into a plain "no".
            let center = UNUserNotificationCenter.current()
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    // MARK: Keeping iOS up to date

    /// Where the bookkeeping is kept. `UserDefaults` is a small key-value
    /// store that belongs to this app on this phone (the `@AppStorage` from
    /// 4b is built on it). Like the web's localStorage, it never syncs.
    private static let firedKey = "classping.reminders.fired"
    private static let scheduledKey = "classping.reminders.scheduled"

    /// Notification-center calls suspend, so main-actor isolation alone doesn't
    /// stop two syncs interleaving their remove/add operations. Keep one writer;
    /// edits during a batch request another pass using the latest store values.
    private static var reminderSyncInProgress = false
    private static var reminderSyncRequested = false

    /// Rebuilds the plan and hands it to iOS. Safe to call as often as you
    /// like: each call replaces the whole waiting list, and a reminder's id
    /// stops it ringing twice. The web's 30-second loop, done once per change.
    func syncReminders() async {
        guard !Task.isCancelled else { return }
        Store.reminderSyncRequested = true
        guard !Store.reminderSyncInProgress else { return }
        Store.reminderSyncInProgress = true
        defer { Store.reminderSyncInProgress = false }

        // Finish a batch even if SwiftUI cancels its caller after an edit.
        // The newer call marks another pass, rather than racing this writer.
        while Store.reminderSyncRequested {
            Store.reminderSyncRequested = false
            await replaceReminders()
        }
    }

    private func replaceReminders() async {
        let inputs = reminderInputs
        let now = Date.now
        let defaults = UserDefaults.standard

        // 1. What has rung since last time: the last plan's one-offs whose
        //    moment has passed, on top of what was already known.
        //    `as? [String: Double]` reads the saved dictionary back as the
        //    type it was saved as, or gives nil (then `?? [:]`, an empty one).
        let oldFired = Set(defaults.stringArray(forKey: Store.firedKey) ?? [])
        let oldTimes = defaults.dictionary(forKey: Store.scheduledKey) as? [String: Double] ?? [:]
        let scheduled = oldTimes.mapValues { Date(timeIntervalSince1970: $0) }
        let liveIDs = Set(liveAssignments.map { $0.id.uuidString })
        let fired = settledFired(oldFired, scheduled: scheduled, now: now, liveTaskIDs: liveIDs)

        // 2. What should ring from now on.
        let quiet = normalizeQuietHours(start: profile.quietStart, end: profile.quietEnd)
        let plan = reminderPlan(courses: liveCourses, tasks: liveAssignments,
                                postClass: profile.postClassNudge, quiet: quiet,
                                fired: fired, now: now)

        // 3. Permission, asked the first time there is something to ring (D-30).
        var allowed = false
        if !plan.isEmpty {
            allowed = await requestNotificationAccess()
        }
        // Permission can stay open for minutes. Re-plan against the current
        // clock and data before handing iOS anything calculated before it.
        guard inputs == reminderInputs, dayOf(now) == dayOf(.now),
              minuteOfDay(now) == minuteOfDay(.now) else {
            Store.reminderSyncRequested = true
            return
        }

        // 4. Write down what's about to go to iOS before it goes, so even if
        //    this is interrupted nothing can ring twice. Only one-offs are
        //    recorded; a weekly reminder never finishes.
        var times: [String: Double] = [:]
        if allowed {
            for r in plan {
                if case .once(let date) = r.timing {
                    times[r.id] = date.timeIntervalSince1970
                }
            }
        }
        defaults.set(Array(fired), forKey: Store.firedKey)
        defaults.set(times, forKey: Store.scheduledKey)

        // 5. Replace iOS's waiting list with the new plan.
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard allowed else { return }
        for r in plan {
            // A rejected one-off must stay eligible for the next sync, even
            // if its planned date has passed by then.
            if (try? await center.add(notificationRequest(for: r))) == nil {
                times.removeValue(forKey: r.id)
                defaults.set(times, forKey: Store.scheduledKey)
            }
        }
        if inputs != reminderInputs { Store.reminderSyncRequested = true }
    }

    /// One planned reminder as an iOS notification request: what it says,
    /// and when it rings.
    private func notificationRequest(for r: PlannedReminder) -> UNNotificationRequest {
        // What the notification shows.
        let content = UNMutableNotificationContent()
        content.title = r.title
        content.body = r.body
        content.sound = .default
        // Groups ClassPing's notifications by kind in Notification Center.
        content.threadIdentifier = r.kind.rawValue
        // Details a tap can read later (Phase 7c opens the right screen).
        content.userInfo = ["kind": r.kind.rawValue,
                            "course": r.courseID?.uuidString ?? "",
                            "assignment": r.assignmentID?.uuidString ?? ""]
        return UNNotificationRequest(identifier: r.id, content: content,
                                     trigger: trigger(for: r.timing))
    }

    /// When it rings, as an iOS trigger. A calendar trigger names a clock time
    /// ("Monday 9:45 AM"), so it still rings at 9:45 after a daylight-saving
    /// change or in another time zone: a ClassPing time is always local time.
    /// Nil means "right away".
    private func trigger(for timing: ReminderTiming) -> UNNotificationTrigger? {
        let cal = Calendar.current
        switch timing {
        case .once(let date):
            // Already due (a catch-up): no trigger, so iOS shows it at once.
            // Compared with the clock now, not when the plan was made: the
            // permission box may have been open for a while.
            guard date > Date.now.addingTimeInterval(1) else { return nil }
            let parts = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            return UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        case .weekly(let first):
            // Only weekday, hour and minute: iOS rings each time all three
            // match, which is once a week. The calendar gives Apple's weekday
            // number (1 = Sunday) itself, so nothing converts days by hand.
            let parts = cal.dateComponents([.weekday, .hour, .minute], from: first)
            return UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        }
    }
}
