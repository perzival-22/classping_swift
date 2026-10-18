//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/TaskReminderCard.swift
//  Phase:   7b (one task's reminders, and planning the work)
//  Ports:   TaskReminderCard in components/TaskReminders.tsx
//
//  Summary: The Reminders card on a task's detail: the daily nudge switch,
//           "Warn me early" (1 week, 3 days, 2 days before), and "Not now",
//           four ways to snooze it, or, while it's snoozed, until when and a
//           Wake it button. These live on the task, not in Profile, because
//           they belong to this piece of work.
//

import SwiftUI

struct TaskReminderCard: View {
    @Environment(Store.self) private var store

    /// The task, freshly looked up by the detail screen on every redraw.
    let assignment: Assignment

    var body: some View {
        // Redraw every minute (`TimelineView`, 5a), so a snooze that runs out
        // turns back into the four buttons by itself.
        TimelineView(.everyMinute) { context in
            content(context.date)
        }
    }

    /// The card at a given moment.
    private func content(_ now: Date) -> some View {
        let a = assignment
        let accent = store.profile.accent
        let leads = effectiveLeads(a)
        let chosen = normalizeLeads(a.remindLeads) != nil

        return VStack(alignment: .leading, spacing: 14) {
            // MARK: The switch
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel("Reminders")
                    Text(a.due == nil
                         ? "Give this a deadline and we can nudge you about it."
                         : a.reminder
                            ? "A nudge each day from 24 hours out, until it's ticked off."
                            : "No nudges for this one.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                // A Binding(get:set:) (5b): reads the task, writes through the store.
                Toggle("Reminders", isOn: Binding(get: { a.reminder },
                                                  set: { store.setReminder($0, for: a.id) }))
                    .labelsHidden()
            }

            // The rest only matters for a dated task with its reminder on.
            if a.reminder && a.due != nil {
                // MARK: Warn me early
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Warn me early")
                    chipGrid {
                        ForEach(leadChoices) { choice in
                            chip(choice.label, on: leads.contains(choice.minutes), accent) {
                                store.toggleLead(choice.minutes, for: a.id)
                            }
                        }
                    }
                    Text(leadCaption(leads, chosen: chosen))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // MARK: Not now
                if isSnoozed(a.snoozedUntil, now), let until = a.snoozedUntil {
                    // Snoozed: say until when, and offer to end it early.
                    HStack(spacing: 12) {
                        // A `Text` can be dropped into another Text's string,
                        // so one sentence can have a bold part in the middle.
                        Text("Snoozed until \(Text(snoozeLabel(until, now)).fontWeight(.semibold).foregroundStyle(Theme.ink)).")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                        Spacer(minLength: 8)
                        Button {
                            store.wake(a.id)
                        } label: {
                            Text("Wake it")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.brand(accent))
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(Theme.brandSoft(accent),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Not now")
                        chipGrid {
                            // `allCases` (from CaseIterable) lists the four presets in order.
                            ForEach(SnoozePreset.allCases) { preset in
                                chip(preset.label, on: false, accent) {
                                    store.snooze(a.id, preset, now: now)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Pieces

    /// The line under the warning chips. The same three sentences as the web.
    private func leadCaption(_ leads: [Int], chosen: Bool) -> String {
        if leads.isEmpty { return "Just the daily nudge." }
        let names = leads.map(leadLabel).joined(separator: ", ")
        return chosen
            ? "One heads-up at \(names) before."
            : "Exams get \(names) by default, tap to change."
    }

    /// "8:00 AM", "tomorrow 8:00 AM" or "Sep 12 6:00 PM": enough to trust a
    /// snooze. `whenLabel` in TaskReminders.tsx, which writes the time as
    /// 08:00; the phone uses the 12-hour clock it shows everywhere else.
    private func snoozeLabel(_ until: Date, _ now: Date) -> String {
        let time = fmtTime(minuteOfDay(until))
        if dayOf(until) == dayOf(now) { return time }
        if dayOf(until) == dayOf(scheduleDate(now, 1)) { return "tomorrow \(time)" }
        return "\(fmtMD(until)) \(time)"
    }

    /// Chips that wrap onto another row when they don't fit. A `LazyVGrid`
    /// with one `.adaptive` column fits as many columns of at least 100 points
    /// as the width allows, and stretches them to share it. On the web,
    /// `flex-wrap` does the same job.
    private func chipGrid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
                  alignment: .leading, spacing: 8) {
            content()
        }
    }

    /// One chip: brand-filled when on, a quiet grey when off.
    private func chip(_ label: String, on: Bool, _ accent: Profile.Accent,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(on ? Color.white : Theme.muted2)
                .background(on ? Theme.brand(accent) : Theme.surface2,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// A small capital-letter label, like the web's "REMINDERS".
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.faint)
    }
}
