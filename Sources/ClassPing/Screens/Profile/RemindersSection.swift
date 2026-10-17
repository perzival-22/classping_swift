//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/RemindersSection.swift
//  Phase:   7a (reminders ring)
//  Ports:   the Reminders card of app/settings/page.tsx (the after-class
//           nudge) and components/QuietHours.tsx (QuietHoursRow)
//
//  Summary: The Reminders card in the Profile tab: whether iOS lets ClassPing
//           ring at all (with a way to fix it), the after-class nudge switch,
//           and quiet hours with their two times. Changes save through
//           ProfileView, which saves whenever the profile changes.
//

import SwiftUI
import UIKit   // for the address of the Settings app's notification page

struct RemindersSection: View {
    @Environment(Store.self) private var store

    /// Opens a link: here, the Settings app on ClassPing's own page.
    @Environment(\.openURL) private var openURL

    /// On screen or not. Read so the card can ask iOS again when you come
    /// back from the Settings app.
    @Environment(\.scenePhase) private var scenePhase

    /// What iOS says about notifications, or nil until it has answered.
    @State private var access: NotificationAccess? = nil

    var body: some View {
        // `@Bindable` lets the switch write straight into the store (Phase 3).
        @Bindable var store = store
        let quiet = normalizeQuietHours(start: store.profile.quietStart,
                                        end: store.profile.quietEnd)

        VStack(alignment: .leading, spacing: 14) {
            Text("REMINDERS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)

            // MARK: Permission
            accessNotice

            // MARK: After-class nudge
            row("bell.fill", "After-class nudge",
                "When a class ends, we'll ask if it came with an assignment, so you log it before you forget.") {
                Toggle("After-class nudge", isOn: $store.profile.postClassNudge)
                    .labelsHidden()
            }
            footnote(store.profile.postClassNudge
                     ? "On, the moment a class ends, even when ClassPing is closed."
                     : "Off, no reminder when a class ends.")

            Divider()

            // MARK: Quiet hours
            row("moon.fill", "Quiet hours",
                "Hold reminders overnight. A class alarm still rings, you set that one yourself.") {
                Toggle("Quiet hours", isOn: quietOn)
                    .labelsHidden()
            }
            // The two times, only while quiet hours are on.
            if let quiet {
                HStack(alignment: .bottom, spacing: 12) {
                    timeBox("From", quiet.start) { setQuiet(start: $0) }
                    Text("to")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.faint)
                        .padding(.bottom, 8)
                    timeBox("Until", quiet.end) { setQuiet(end: $0) }
                }
                .padding(.leading, 48)
            }
            // The line under it. `TimelineView` (5a) redraws it every minute,
            // so "Quiet now" switches on and off by itself.
            TimelineView(.everyMinute) { context in
                footnote(quietSummary(quiet, context.date))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        // Ask iOS when the card appears, and again each time the app comes
        // back, in case you just changed it in Settings. `.task(id:)` re-runs
        // whenever `scenePhase` changes.
        .task(id: scenePhase) {
            access = await store.notificationAccess()
        }
    }

    // MARK: - Pieces

    /// What to say when iOS won't ring for ClassPing, or hasn't asked yet.
    /// Nothing at all once notifications are allowed. `@ViewBuilder` lets one
    /// property hand back different views from different `switch` cases.
    @ViewBuilder private var accessNotice: some View {
        switch access {
        case .blocked:
            notice("Notifications are off for ClassPing, so nothing can ring. Turn them on in Settings.",
                   button: "Open Settings") {
                // The Settings app's page for this app's notifications.
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            }
        case .notAsked:
            notice("ClassPing needs your OK before it can ring for classes and deadlines.",
                   button: "Allow notifications") {
                // A button's action can't wait, so `Task { }` starts a piece
                // of async work that runs on its own: ask iOS, read the answer
                // back for this card, then plan the reminders.
                Task {
                    _ = await store.requestNotificationAccess()
                    access = await store.notificationAccess()
                    await store.syncReminders()
                }
            }
        case .allowed, nil:
            EmptyView()
        }
    }

    /// The switch for quiet hours, as a true/false binding (`Binding(get:set:)`
    /// from 5b). On writes the default 10 PM to 7 AM window; off clears both
    /// times, which is how "off" is stored on the web too.
    private var quietOn: Binding<Bool> {
        Binding(
            get: {
                normalizeQuietHours(start: store.profile.quietStart,
                                    end: store.profile.quietEnd) != nil
            },
            set: { on in
                store.profile.quietStart = on ? defaultQuietHours.start : nil
                store.profile.quietEnd = on ? defaultQuietHours.end : nil
            })
    }

    /// Moves one end of the window. Two equal ends would be an empty window,
    /// which means "off", so the end moves on a minute instead of the whole
    /// feature switching off under you. `setEnd` in QuietHours.tsx.
    private func setQuiet(start: Int? = nil, end: Int? = nil) {
        guard var next = normalizeQuietHours(start: store.profile.quietStart,
                                             end: store.profile.quietEnd) else { return }
        if let start { next.start = start }
        if let end { next.end = end }
        if next.start == next.end { next.end = (next.end + 1) % 1440 }
        store.profile.quietStart = next.start
        store.profile.quietEnd = next.end
    }

    /// The line under quiet hours. Same three sentences as the web.
    private func quietSummary(_ quiet: QuietHours?, _ now: Date) -> String {
        guard let quiet else { return "Off, reminders can arrive at any hour." }
        if inQuietHours(minuteOfDay(now), quiet) {
            return "Quiet now, nudges resume at \(fmtTime(quiet.end))."
        }
        return "On, nothing between \(fmtTime(quiet.start)) and \(fmtTime(quiet.end)), except a class alarm."
    }

    /// One setting: a soft brand tile with a symbol, a title and a sentence,
    /// and its control on the right. `<Control: View>` lets the caller pass
    /// any view as the control (here, always a Toggle).
    private func row<Control: View>(_ symbol: String, _ title: String, _ text: String,
                                    @ViewBuilder control: () -> Control) -> some View {
        let accent = store.profile.accent
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(Theme.brand(accent))
                .frame(width: 36, height: 36)
                .background(Theme.brandSoft(accent),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            control()
        }
    }

    /// One end of the quiet window: a small label over a time picker. The
    /// picker wants a Date, the profile stores minutes, so the binding
    /// converts both ways: minutes to today at that time, and back.
    private func timeBox(_ label: String, _ minutes: Int,
                         _ set: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
            DatePicker(label,
                       selection: Binding(get: { atMinute(.now, minutes) },
                                          set: { set(minuteOfDay($0)) }),
                       displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    /// The small grey line under a setting.
    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.faint)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A tinted box with a sentence and one button, for the permission states.
    private func notice(_ text: String, button: String,
                        action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.dangerInk)
                .fixedSize(horizontal: false, vertical: true)
            Button(button, action: action)
                .font(.system(size: 13.5, weight: .semibold))
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.dangerSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
