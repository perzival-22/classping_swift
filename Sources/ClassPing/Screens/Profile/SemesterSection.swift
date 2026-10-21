//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/SemesterSection.swift
//  Phase:   11a (settings: you, the look, grading and the term)
//  Ports:   the Semester card of app/settings/page.tsx, with `CurrentTerm`
//           and `DateBox`
//
//  Summary: The term's name and its first and last days, how far through it
//           you are, and "Start a new term", which files this term's classes
//           under its name so the timetable starts clean. The name saves when
//           you leave the field, a date as soon as you pick it, like the web.
//

import SwiftUI

struct SemesterSection: View {
    @Environment(Store.self) private var store

    /// The term name as typed; saved when the field loses focus.
    @State private var name = ""
    @FocusState private var typing: Bool

    /// "Start a new term" was tapped: the naming step is showing.
    @State private var archiving = false
    /// The name typed for the term being archived.
    @State private var archiveName = ""
    @FocusState private var namingArchive: Bool
    /// Shows "Term archived…" for a few seconds after it worked.
    @State private var archived = false
    /// A save that didn't reach planner.json, in words, or nil.
    @State private var problem: String? = nil

    var body: some View {
        let accent = store.profile.accent
        let start = store.profile.termStart
        let end = store.profile.termEnd
        // Live classes still on the timetable: what "Start a new term" files away.
        let classes = store.activeCourses.count

        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SEMESTER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.faint)
                    .accessibilityAddTraits(.isHeader)

                // MARK: Current term
                fieldLabel("CURRENT TERM")
                TextField("e.g. Fall 2025", text: $name)
                    .focused($typing)
                    .submitLabel(.done)
                    .onSubmit { saveName() }
                    // The web's field stops at 64 characters; so does this one.
                    .onChange(of: name) { _, typed in
                        if typed.count > 64 { name = String(typed.prefix(64)) }
                    }
                    .inputField(accent)

                // MARK: The two days
                dateRow("SEMESTER STARTS", day: start, accent: accent) { picked in
                    store.setTermDates(start: picked, end: store.profile.termEnd)
                }
                dateRow("SEMESTER ENDS", day: end, accent: accent) { picked in
                    store.setTermDates(start: store.profile.termStart, end: picked)
                }

                // MARK: How far through
                // `TimelineView` (5a) redraws this each minute, so the count
                // moves on at midnight without leaving the tab.
                TimelineView(.everyMinute) { context in
                    let note = termNote(start: start, end: end, now: context.date)
                    VStack(alignment: .leading, spacing: 8) {
                        if note.showsWindow {
                            Text(TERM_WINDOW_NOTE)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.faint)
                        }
                        if let fraction = note.fraction {
                            ProgressView(value: fraction)
                                .tint(Theme.brand(accent))
                            Text(note.line)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.muted)
                        } else {
                            Text(note.line)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.faint)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }

                if let problem {
                    Text(problem)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.danger)
                }

                // MARK: Start a new term
                if classes > 0 {
                    Divider().padding(.vertical, 4)
                    Text("Finished the semester? Archive these \(classes) \(classes == 1 ? "class" : "classes") to clear your timetable. Their grades stay on the Grades screen under the term name.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if archiving {
                        archiveStep(accent)
                    } else {
                        Button {
                            archiveName = store.profile.termName ?? ""
                            archiving = true
                        } label: {
                            Text("Start a new term")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.brand(accent))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()

            if archived {
                Text("Term archived, your timetable is clear. 🎉")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.brand(accent))
            }
        }
        .onAppear { name = store.profile.termName ?? "" }
        // Archiving (or anything else) changed the saved name: show it,
        // unless you're typing, so the field never writes a stale name back.
        .onChange(of: store.profile.termName) { _, saved in
            if !typing { name = saved ?? "" }
        }
        .onChange(of: typing) { _, isTyping in
            if !isTyping { saveName() }
        }
        // The "archived" line goes away after 4 seconds, as on the web.
        .task(id: archived) {
            guard archived else { return }
            try? await Task.sleep(for: .seconds(4))
            archived = false
        }
    }

    /// The small caps over a field, like the web's labels inside the box.
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Theme.faint)
    }

    /// One of the semester's days. Unset: an "Add date" button. Set: a date
    /// picker, kept on its side of the other day, and a button to clear it.
    /// `save` gets the new day as "yyyy-MM-dd", or nil to clear it.
    private func dateRow(_ label: String, day: String?, accent: Profile.Accent,
                         save: @escaping (String?) -> Bool) -> some View {
        HStack {
            fieldLabel(label)
            Spacer()
            if let date = dayStart(day) {
                DatePicker(label, selection: Binding(
                    get: { date },
                    set: { report(save(dayOf($0))) }
                ), in: range(for: label), displayedComponents: .date)
                .labelsHidden()
                .tint(Theme.brand(accent))
                Button {
                    report(save(nil))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.faint)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear \(label.lowercased())")
            } else {
                Button("Add date") {
                    report(save(dayOf(firstGuess(for: label))))
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(minHeight: 44)
                .tint(Theme.brand(accent))
            }
        }
    }

    /// Either date can be moved independently. The web allows an end before
    /// the start and calls that out in the card, so don't clamp one to the
    /// other here.
    private func range(for _: String) -> ClosedRange<Date> {
        Date.distantPast...Date.distantFuture
    }

    /// Where "Add date" starts you: today, unless that would land on the
    /// wrong side of the other day; then the other day itself.
    private func firstGuess(for label: String) -> Date {
        let today = Calendar.current.startOfDay(for: .now)
        if label == "SEMESTER STARTS" {
            return min(today, dayStart(store.profile.termEnd) ?? today)
        }
        return max(today, dayStart(store.profile.termStart) ?? today)
    }

    /// Shows the save message when a write didn't reach planner.json.
    private func report(_ saved: Bool) {
        problem = saved ? nil : "Couldn't save on this device. Try again."
    }

    /// Saves the typed term name, then shows it as saved (trimmed).
    private func saveName() {
        report(store.setTermName(name))
        name = store.profile.termName ?? ""
    }

    /// Naming the term being archived, then Cancel or Archive.
    @ViewBuilder
    private func archiveStep(_ accent: Profile.Accent) -> some View {
        fieldLabel("NAME THIS TERM")
        TextField("e.g. Fall 2025", text: $archiveName)
            .focused($namingArchive)
            .submitLabel(.done)
            .inputField(accent)
        HStack(spacing: 10) {
            Button {
                archiving = false
                archiveName = ""
            } label: {
                Text("Cancel")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(Theme.muted)

            Button {
                namingArchive = false
                if store.archiveTerm(archiveName) {
                    archiving = false
                    archiveName = ""
                    problem = nil
                    archived = true
                } else {
                    report(false)
                }
            } label: {
                Text("Archive")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand(accent))
            .disabled(archiveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
