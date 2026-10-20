//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Grades/FinalsCountdown.swift
//  Phase:   9c (finals countdown and the CSV report), changed in 9b+ (D-58)
//           and again after its phone check (D-60)
//  Ports:   components/FinalsCountdown.tsx
//
//  Summary: The Days to Finals card on Grades: a live count of the days left
//           until your finals date, and a small form to set, change or clear
//           it. The date is saved on your profile, as on the web. Since D-60
//           the picker and Save only appear after you ask for them, so Clear
//           can't be followed by a Save of a date you never picked.
//

import SwiftUI

struct FinalsCountdown: View {
    @Environment(Store.self) private var store

    /// True while the picker is open: setting a first date, or changing one.
    @State private var editing = false
    /// The day in the picker, before you tap Save.
    @State private var draft = Date.now
    /// True when the last Save or Clear couldn't be written to the phone.
    @State private var failed = false

    var body: some View {
        let accent = store.profile.accent
        let saved = store.profile.finalsDate
        // A saved date that isn't a real day counts as none, so the card asks again.
        let hasDate = isValidDate(saved)

        VStack(alignment: .leading, spacing: 12) {
            // The label, with Edit beside it while the countdown shows.
            HStack {
                Text("DAYS TO FINALS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if hasDate && !editing {
                    Button("Edit") { openEditor(saved) }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.brandDeep(accent))
                        .frame(minHeight: 44)
                        .accessibilityLabel("Edit finals date")
                }
            }

            // Three states: picker, countdown, or a prompt to set a date.
            if editing {
                editor(hasDate: hasDate)
            } else if hasDate {
                // TimelineView (5a) redraws once a minute, so the count turns
                // over at midnight even if this screen stays open.
                TimelineView(.everyMinute) { context in
                    if let status = finalsStatus(saved, context.date) {
                        countdown(status, accent)
                    }
                }
            } else {
                empty
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// The big number (or Today, or Done) and the sentence under it.
    private func countdown(_ status: FinalsStatus, _ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(status.headline)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.brandDeep(accent))
                if let unit = status.unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            Text(status.message)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        // One VoiceOver stop: "51, days, Finals begin Thursday, Dec 10. …"
        .accessibilityElement(children: .combine)
    }

    /// No date yet, or just cleared: offer the web's prompt with a button
    /// instead of an open picker.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add your finals date to see a live countdown.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            Button("Set finals date") { openEditor(nil) }
                .buttonStyle(.borderedProminent)
        }
    }

    /// The picker, to set a first date or change the one you have.
    private func editor(hasDate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hasDate ? "Update your finals date." : "Pick the first day of your finals.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)

            // Date only, like the planner's picker in 7b. The compact style
            // shows the day as a button that opens a calendar.
            DatePicker("Finals date", selection: $draft, displayedComponents: .date)

            HStack(spacing: 8) {
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                if hasDate {
                    Button("Clear", action: clear)
                        .buttonStyle(.bordered)
                }
                Button("Cancel") {
                    editing = false
                    failed = false
                }
            }

            // The screen's own banner sits far above this card, so say it here too.
            if failed {
                Text("Couldn't save on this device. Try again.")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            }
        }
    }

    /// Open the picker on the saved day, or today when there isn't one.
    private func openEditor(_ saved: String?) {
        // `deadlineDayStart` turns "2026-12-10" into local midnight that day.
        draft = deadlineDayStart(makeDeadline(saved, nil)) ?? .now
        failed = false
        editing = true
    }

    /// Save the picked day as "yyyy-MM-dd" (`dayOf`: your own calendar day,
    /// never UTC's). The form stays open with a red line if the phone
    /// couldn't write it.
    private func save() {
        failed = !store.setFinalsDate(dayOf(draft))
        if !failed { editing = false }
    }

    /// Remove the date. Close the picker so the next tap can't re-save it.
    private func clear() {
        failed = !store.setFinalsDate(nil)
        if !failed { editing = false }
    }
}
