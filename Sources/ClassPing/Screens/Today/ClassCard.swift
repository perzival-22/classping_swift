//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Today/ClassCard.swift
//  Phase:   6a (Today: the picked day)
//  Ports:   ClassCard, ClassDetail and fmtRange in app/home/page.tsx
//
//  Summary: One class meeting on the picked day: the color bar, the book, the
//           name, the time and room, and a Now / Done / reminder-time tag. It
//           starts open, showing the days, time, room, teacher and your notes,
//           because between classes the room is what you need. Tap it to fold.
//

import SwiftUI

/// "9:00 – 10:15 AM", or "11:00 AM – 12:15 PM" when it crosses noon.
/// `fmtRange` in app/home/page.tsx. Built on `fmtTime` from Phase 2, which
/// always ends in " AM" or " PM".
func fmtRange(_ start: Int, _ end: Int) -> String {
    let from = fmtTime(start)
    let to = fmtTime(end)
    // Same half of the day: say AM or PM once, at the end, by cutting the
    // last three characters (" AM") off the start time.
    return from.suffix(2) == to.suffix(2) ? "\(from.dropLast(3)) – \(to)" : "\(from) – \(to)"
}

struct ClassCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The meeting to show and the class it belongs to (Phase 5a's slot).
    let slot: MeetingSlot<Course>
    /// Minutes since midnight right now, or -1 when the picked day isn't
    /// today, so nothing is marked Now or Done. The web's `nowMin`.
    let nowMin: Int

    /// Open or folded. This is the card's OWN state: every ClassCard in the
    /// list gets a separate `open`, kept for as long as that card stays on
    /// screen. SwiftUI tells the cards apart by the `id` the ForEach in
    /// TodayView gives them, so folding Biology never folds Chemistry.
    /// Starts folded so the day's classes fit side by side. Tap any tile to
    /// open its full room, teacher and notes details.
    @State private var open = false

    var body: some View {
        let course = slot.course
        let meeting = slot.meeting
        // -1 means another date; midnight (0) is still a valid time today.
        let isPast = nowMin >= 0 && nowMin > meeting.end
        let isNow = nowMin >= 0 && nowMin >= meeting.start && nowMin <= meeting.end
        let range = fmtRange(meeting.start, meeting.end)

        VStack(alignment: .leading, spacing: 0) {
            // The top row: color bar, then a button that folds and unfolds.
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.subject(course.color))
                    .frame(width: 5)

                Button {
                    withAnimation(reduceMotion ? nil : .snappy) { open.toggle() }
                } label: {
                    header(course, meeting, range, isNow: isNow, isPast: isPast)
                }
                .buttonStyle(.plain)
                .accessibilityValue(open ? "Expanded" : "Collapsed")
            }

            // The details drawer, only while open.
            if open {
                details(course, meeting, range)
            }
        }
        // The card surface. Clipped to the rounded shape so the color bar's
        // corners are rounded too, then the shadow goes on the clipped shape.
        .background(Theme.card)
        .aspectRatio(open ? nil : 1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
        // A class that's over fades back, the web's opacity .55.
        .opacity(isPast ? 0.55 : 1)
    }

    // MARK: - Pieces

    /// Book, name, "9:00 – 10:15 AM · Room 4", the tag and the chevron.
    private func header(_ course: Course, _ meeting: ClassMeeting, _ range: String,
                        isNow: Bool, isPast: Bool) -> some View {
        // The room only when there is one; an empty room counts as none.
        let room = meeting.room.flatMap { $0.isEmpty ? nil : $0 }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                SubjectBook(color: course.color, short: course.short, compact: true)
                Spacer(minLength: 0)
                statusTag(isNow: isNow, isPast: isPast, meeting: meeting)
            }

            Text(course.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(room.map { "\(range) · \($0)" } ?? range)
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.hint)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
        // Makes the whole row tappable, gaps included.
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func statusTag(isNow: Bool, isPast: Bool, meeting: ClassMeeting) -> some View {
        if isNow {
            Text("Now")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.good, in: Capsule())
        } else if isPast {
            Text("Done")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.hint)
        } else if nowMin >= 0 {
            Text(fmtTime(meeting.start))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
    }

    /// Days, time, room, teacher and the class's private note.
    private func details(_ course: Course, _ meeting: ClassMeeting, _ range: String) -> some View {
        // "Mon · Wed · Fri". A day outside 0...6 shows as "?" instead of crashing.
        let days = meeting.days.sorted()
            .map { dayLabels.indices.contains($0) ? dayLabels[$0] : "?" }
            .joined(separator: " · ")
        let room = meeting.room ?? ""
        let teacher = course.instructor ?? ""
        let notes = course.notes ?? ""

        return VStack(alignment: .leading, spacing: 0) {
            detailRow("Days", days)
            detailRow("Time", range)
            // The web skips empty values: `{c.room && ...}`.
            if !room.isEmpty { detailRow("Room", room) }
            if !teacher.isEmpty { detailRow("Teacher", teacher) }
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted2)
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            }
        }
        .padding(.leading, 52)
        .padding(.trailing, 16)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The faint line between the row and the drawer.
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    /// One "Label   value" line. `ClassDetail` in app/home/page.tsx.
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted2)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }
}
