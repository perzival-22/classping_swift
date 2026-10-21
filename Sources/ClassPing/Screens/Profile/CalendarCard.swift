//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/CalendarCard.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   the "Add to phone calendar" part of the Reminders card in
//           app/settings/page.tsx (handleCalendarExport) and
//           downloadCalendarFile in lib/calendar.ts
//
//  Summary: The Profile tab's Calendar card. One button opens the share sheet
//           with classping.ics: this term's timetable and your open, dated
//           work, built on the phone. The web builds the same file on its
//           server, for Pro accounts only; the phone needs neither (D-77).
//

import SwiftUI
import UniformTypeIdentifiers

/// The calendar file, as something the share sheet can send: a .ics file.
/// The same idea as `GradeReportFile` in Phase 9c: it carries what the file
/// is made from, and makes the file only when you pick where it goes.
struct CalendarFile: Transferable {
    /// The classes on the timetable now (not archived, not deleted).
    let courses: [Course]
    /// Your work (not deleted); the file leaves out what's done or undated.
    let assignments: [Assignment]
    /// The semester, so the weekly events stop when it ends.
    let term: TermWindow

    /// The file's text at `now`. A piece of work names its class only when
    /// that class is in the file, as the web's server does.
    func text(at now: Date) -> String {
        let names = Dictionary(courses.map { ($0.id, $0.name) },
                               uniquingKeysWith: { first, _ in first })
        return buildCalendarFile(courses, assignments,
                                 className: { id in id.flatMap { names[$0] } },
                                 now: now, term: term)
    }

    /// One form: a file of type "calendar event" (`.calendarEvent`, the
    /// kind of file .ics is), named classping.ics like the web's download.
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .calendarEvent) { file in
            let url = URL.temporaryDirectory.appending(path: "classping.ics")
            let data = Data(file.text(at: .now).utf8)
            // Throwing tells the share sheet the file couldn't be made, rather
            // than handing over one that isn't there (as in 9c).
            guard (try? data.write(to: url, options: .atomic)) != nil else {
                throw CocoaError(.fileWriteUnknown)
            }
            return SentTransferredFile(url)
        }
    }
}

struct CalendarCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let accent = store.profile.accent
        let courses = store.activeCourses
        let open = store.liveAssignments.filter { !$0.done }
        // Nothing to put in a calendar yet: the button waits, as on the web.
        let hasSchedule = !courses.isEmpty || !open.isEmpty

        VStack(alignment: .leading, spacing: 12) {
            Text("CALENDAR")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
                .accessibilityAddTraits(.isHeader)

            // The web's calendar icon and its sentence.
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.brand(accent))
                    .frame(width: 36, height: 36)
                    .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                Text("Prefer your own calendar? Add your schedule to it and your phone will deliver the class reminders too.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The share sheet, with the file made when you pick where it goes.
            ShareLink(item: CalendarFile(courses: courses, assignments: store.liveAssignments,
                                         term: TermWindow(start: store.profile.termStart,
                                                          end: store.profile.termEnd)),
                      preview: SharePreview("ClassPing timetable",
                                            image: Image(systemName: "calendar"))) {
                Text("Add to phone calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand(accent))
            .disabled(!hasSchedule)

            // What goes in, or why the button is waiting.
            Text(calendarSummary(classes: courses.count, openTasks: open.count))
                .font(.system(size: 12))
                .foregroundStyle(Theme.faint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
