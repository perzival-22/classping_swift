//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Import/TermSetupSheet.swift
//  Phase:   13a (import a calendar or schedule file)
//  Ports:   components/TermSetupSheet.tsx
//
//  Summary: The one-time question after your first import (and, from 13b,
//           your first class): when does your semester run? When the file
//           suggested days, it asks you to confirm them. Not now, or a swipe
//           down, means it won't ask again; the Semester card on Profile
//           changes the days any time.
//

import SwiftUI

struct TermSetupSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The days the import suggested, or nil (a first class suggests none).
    let suggestion: TermDateSuggestion?

    /// The two days as "yyyy-MM-dd", nil until set.
    @State private var start: String?
    @State private var end: String?
    /// Why Save can't go ahead, or nil.
    @State private var error: String? = nil

    /// The days start as the suggestion's. `_start` is the State itself,
    /// so `State(initialValue:)` gives it its first value (Phase 4a).
    init(suggestion: TermDateSuggestion?) {
        self.suggestion = suggestion
        _start = State(initialValue: suggestion?.start)
        _end = State(initialValue: suggestion?.end)
    }

    var body: some View {
        let accent = store.profile.accent
        // A whole range was suggested: confirm it rather than ask for it.
        let foundRange = suggestion?.end != nil

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.brand(accent))
                    .frame(width: 40, height: 40)
                    .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 13))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(foundRange ? "We found a term" : "When does your semester run?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(explanation(foundRange))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 6) {
                dateRow("SEMESTER STARTS", $start, accent)
                dateRow("SEMESTER ENDS", $end, accent)
            }

            if let error {
                Text(error)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.danger)
            }

            HStack(spacing: 10) {
                Button {
                    store.finishTermSetup()
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .tint(Theme.muted)

                Button { save() } label: {
                    Text("Save semester dates")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand(accent))
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas)
        // A sheet that rises only halfway, like the web's bottom sheet, and
        // can be pulled up to full height. Each "detent" is a height it rests at.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // A swipe down counts as Not now, as the web's Escape key does. Save
        // and Not now have already recorded it, so this only fills the gap.
        .onDisappear {
            if !store.profile.termSetupPrompted { store.finishTermSetup() }
        }
    }

    /// The line under the title: the found range, or why to set one.
    private func explanation(_ foundRange: Bool) -> String {
        if foundRange, let first = dayStart(start), let last = dayStart(end) {
            return "We found a term from \(label(first)) to \(label(last)). Use these dates?"
        }
        return "Set this once to keep your timetable and grade report in the right term. You can change it later on the Profile tab."
    }

    /// "Aug 31", in your phone's language. The web's `dateLabel`.
    private func label(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// One of the two days: a date picker once set, "Add date" before. The
    /// same row as the Semester card's (11a).
    private func dateRow(_ title: String, _ day: Binding<String?>, _ accent: Profile.Accent) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted2)
            Spacer()
            if let date = dayStart(day.wrappedValue) {
                DatePicker(title, selection: Binding(
                    get: { date },
                    set: { picked in
                        day.wrappedValue = dayOf(picked)
                        error = nil
                    }
                ), displayedComponents: .date)
                .labelsHidden()
                .tint(Theme.brand(accent))
            } else {
                Button("Add date") {
                    day.wrappedValue = dayOf(.now)
                    error = nil
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(minHeight: 44)
                .tint(Theme.brand(accent))
            }
        }
    }

    /// Save: both days, the end not before the start, in the web's words.
    /// "yyyy-MM-dd" text sorts the way the days do, so `<` compares them.
    private func save() {
        guard let start, let end else {
            error = "Add both dates, or choose Not now."
            return
        }
        if end < start {
            error = "Your semester end date needs to be after its start date."
            return
        }
        if store.finishTermSetup(start: start, end: end) {
            dismiss()
        } else {
            error = "Couldn't save on this device. Try again."
        }
    }
}
