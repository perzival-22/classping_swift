//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Import/ImportView.swift
//  Phase:   13a (import a calendar or schedule file), changed in 13b (Paste
//           a timetable; the sheet's `onImported`, for the class form)
//  Ports:   components/ImportCalendar.tsx (ImportPanel, ImportCalendar and
//           ImportSheet), the file and paste halves
//
//  Summary: Bringing your schedule over from what your school gives you: a
//           calendar (.ics), a schedule spreadsheet (CSV), or a timetable you
//           paste (13b). It's all read on the phone, and you see what it
//           found before anything is added. One panel worn two ways, as on
//           the web: a card on Profile, and a sheet from Today's first-run
//           card and the class form. The live feed link waits for sign-in
//           (Phase 14), a screenshot or PDF for Phase 15 (D-79).
//

import SwiftUI
import UniformTypeIdentifiers

/// Which kind of file the Files picker is open for.
private enum ImportFileKind {
    case calendar      // a .ics file
    case schedule      // a .csv file

    /// The kinds of file the picker offers. `UTType` names a kind of file
    /// (Phase 11b+c). A .ics is a "calendar event" file; its extension is
    /// named as well, in case an app labels a download only by that.
    var types: [UTType] {
        switch self {
        case .calendar: [.calendarEvent] + [UTType(filenameExtension: "ics")].compactMap { $0 }
        case .schedule: [.commaSeparatedText]
        }
    }
}

/// The biggest file read, 3 MB, as on the web. A real school calendar is
/// far smaller.
private let MAX_IMPORT_BYTES = 3 * 1024 * 1024

/// The panel itself: Paste a timetable and the two upload buttons, then a
/// file's preview and Add. `ImportPanel` in components/ImportCalendar.tsx.
struct ImportPanel: View {
    @Environment(Store.self) private var store

    /// Runs once an import, and the term question after it, are finished.
    /// The sheet passes its own close; on Profile it's nil and the card stays.
    var onDone: (() -> Void)? = nil

    /// The Files picker is open, for `kind`.
    @State private var picking = false
    @State private var kind = ImportFileKind.calendar
    /// Why the last file couldn't be used, or nil.
    @State private var error: String? = nil
    /// What the picked file holds, waiting for Add; nil when there's none.
    @State private var found: ImportResult? = nil
    /// How many items the last import added, for the "Added" line.
    @State private var added: Int? = nil
    /// The term question is showing, with the days the file suggested.
    @State private var askingTerm = false
    @State private var suggestion: TermDateSuggestion? = nil

    // NEW in Phase 13b
    /// The paste sheet is open.
    @State private var pasting = false
    /// What the paste sheet reported: added, and whether the term question
    /// follows. nil when it closed without adding anything.
    @State private var pasteAsk: Bool? = nil

    var body: some View {
        let accent = store.profile.accent

        VStack(alignment: .leading, spacing: 12) {
            Text("Upload a calendar (.ics) or schedule CSV from your school. We'll pull out your classes and deadlines, then you review everything before it's added.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text("CSV columns: Course, Days, Start, End. Room, Instructor, Credits, and Semester Start/End are optional.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted2)
                .fixedSize(horizontal: false, vertical: true)

            if let error {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.danger)
            }
            if let added {
                Text("Added \(added) \(added == 1 ? "item" : "items"), find them on your timetable and in Tasks. 🎉")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.brand(accent))
            }

            // A file waiting to be added shows its preview instead of the buttons.
            if let found {
                preview(found, accent)
            } else {
                // NEW in Phase 13b: first, as on the web.
                Button { paste() } label: { wide("Paste a timetable", size: 14) }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand(accent))
                Button { pick(.calendar) } label: { wide("Upload an .ics file", size: 15) }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand(accent))
                Button { pick(.schedule) } label: { wide("Upload a schedule CSV", size: 14) }
                    .buttonStyle(.bordered)
                    .tint(Theme.brand(accent))
            }
        }
        // The Files app's picker, for whichever kind was tapped.
        .fileImporter(isPresented: $picking, allowedContentTypes: kind.types) { result in
            if case .success(let url) = result { open(url) }
        }
        // The term question, after the first import into an empty planner.
        // `onDismiss` runs however it closes, so the panel's job ends there.
        .sheet(isPresented: $askingTerm, onDismiss: { onDone?() }) {
            TermSetupSheet(suggestion: suggestion)
        }
        // NEW in Phase 13b: the paste sheet. It reports back before it closes;
        // `afterPaste` runs once it's gone, so the term question can rise next.
        .sheet(isPresented: $pasting, onDismiss: afterPaste) {
            PasteScheduleView { ask in pasteAsk = ask }
        }
    }

    // MARK: - Pieces

    /// A button's text, full width, at least 48 points tall.
    private func wide(_ title: String, size: CGFloat) -> some View {
        Text(title)
            .font(.system(size: size, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
    }

    /// What the file holds, in two lines, then Cancel and Add.
    @ViewBuilder
    private func preview(_ result: ImportResult, _ accent: Profile.Accent) -> some View {
        let total = result.classes.count + result.tasks.count
        VStack(alignment: .leading, spacing: 2) {
            Text("Ready to import \(total) \(total == 1 ? "item" : "items")")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(counts(result))
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 15))

        HStack(spacing: 10) {
            Button { found = nil } label: { wide("Cancel", size: 15) }
                .buttonStyle(.bordered)
                .tint(Theme.muted)
            Button { confirm(result) } label: { wide("Add \(total)", size: 15) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand(accent))
                .disabled(total == 0)
        }
    }

    /// "1 class · 2 assignments · 3 skipped", the skipped part only when
    /// something was.
    private func counts(_ result: ImportResult) -> String {
        let classes = result.classes.count
        let tasks = result.tasks.count
        var line = "\(classes) \(classes == 1 ? "class" : "classes") · \(tasks) \(tasks == 1 ? "assignment" : "assignments")"
        if result.skipped > 0 { line += " · \(result.skipped) skipped" }
        return line
    }

    // MARK: - Doing it

    /// Opens the picker for one kind of file, clearing the last result.
    private func pick(_ which: ImportFileKind) {
        kind = which
        error = nil
        added = nil
        picking = true
    }

    /// Reads the picked file and finds what's in it, or says why not. The
    /// web's `handleFile` and `handleCsvFile`, with their words. A picked file
    /// lives outside the app, so reading it is wrapped in start and stop
    /// (Phase 11b+c); `defer` makes sure the stop happens.
    private func open(_ url: URL) {
        let reading = url.startAccessingSecurityScopedResource()
        defer { if reading { url.stopAccessingSecurityScopedResource() } }
        let calendar = kind == .calendar

        guard let data = try? Data(contentsOf: url) else {
            error = calendar ? "Couldn't read that file. Try another." : "Couldn't read that CSV. Try another schedule export."
            return
        }
        if data.count > MAX_IMPORT_BYTES {
            error = calendar ? "That file is too large to be a calendar." : "That schedule file is too large."
            return
        }
        // The bytes as UTF-8 text. A byte that isn't valid UTF-8 becomes �,
        // as it does when a browser reads the file, rather than failing.
        let text = String(decoding: data, as: UTF8.self)

        if calendar {
            guard text.contains("BEGIN:VCALENDAR") else {
                error = "That file isn't a calendar (.ics) file."
                return
            }
            let result = parseICS(text)
            guard result.classes.count + result.tasks.count > 0 else {
                error = "No classes or deadlines were found in that file."
                return
            }
            found = result
        } else {
            let result = parseCSVSchedule(text)
            guard !result.classes.isEmpty else {
                error = "No classes were found. Include Course, Days, Start, and End columns."
                return
            }
            found = result
        }
    }

    // NEW in Phase 13b
    /// Paste a timetable: opens the paste sheet, clearing the last result.
    private func paste() {
        error = nil
        added = nil
        pasting = true
    }

    // NEW in Phase 13b
    /// After the paste sheet closes: if it added classes, the term question
    /// follows (a paste suggests no days) or the panel is done, as after a
    /// file. Closed without adding, nothing happens. The web says nothing
    /// after a paste, so neither does the card.
    private func afterPaste() {
        guard let ask = pasteAsk else { return }
        pasteAsk = nil
        if ask {
            suggestion = nil
            askingTerm = true
        } else {
            onDone?()
        }
    }

    /// Add: everything in the preview goes in, in one save. Into an empty,
    /// never-asked planner, the term question follows, with the file's days;
    /// otherwise the panel is done. `confirm` in ImportCalendar.tsx.
    private func confirm(_ result: ImportResult) {
        // Asked before adding: adding is what makes the planner non-empty.
        let ask = store.shouldOfferTermSetup
        guard store.importItems(result.classes, result.tasks) else {
            error = "Couldn't save on this device, so nothing was added. Try again."
            return
        }
        added = result.classes.count + result.tasks.count
        found = nil
        if ask {
            suggestion = result.term
            askingTerm = true
        } else {
            onDone?()
        }
    }
}

/// The Profile tab's card around the panel. `ImportCalendar`.
struct ImportCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("IMPORT FROM YOUR SCHOOL")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
                .accessibilityAddTraits(.isHeader)
            ImportPanel()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

/// The same panel as a sheet, from the one screen where it matters most:
/// Today with no classes yet, and (13b) the class form. `ImportSheet`. It
/// closes itself once the import (and the term question) are done.
struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    // NEW in Phase 13b
    /// Runs when an import finished, just before the sheet closes. The class
    /// form passes "close the form too", as the web's `onImported` leaves it.
    var onImported: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                // CHANGED in Phase 13b: tells the form first, then closes.
                ImportPanel(onDone: {
                    onImported?()
                    dismiss()
                })
                    .padding(20)
            }
            .background(Theme.canvas)
            .navigationTitle("Import your schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
