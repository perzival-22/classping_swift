//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Week/WeekGrid.swift
//  Phase:   5a (the new tab bar and the week)
//  Ports:   app/week/page.tsx (WeekScreen and ClassBlock), opened inside
//           Today instead of on its own tab (D-19)
//
//  Summary: The whole week as a timetable: a heading with week arrows, the
//           seven days, an hour scale, every class as a colored block at its
//           time, a line for "now", and the classes that have no times yet.
//           Today shows it when you open the week; tapping a block calls back.
//

import SwiftUI

struct WeekGrid: View {
    /// The classes to draw (live and unarchived; Today filters them).
    let courses: [Course]
    /// The semester's ends, "yyyy-MM-dd", so days outside it stay empty.
    let termStart: String?
    let termEnd: String?
    /// The moment this redraw is for, from Today's ticking clock.
    let now: Date
    /// Which week is showing: 0 = this week. Shared with the strip.
    @Binding var weekOffset: Int
    let accent: Profile.Accent

    /// What to do when a class block is tapped: the slot, its column
    /// (0 = Monday) and that column's date. A closure, so the grid doesn't
    /// need to know what happens next: Phase 5b's Today opens the class
    /// details. Until then the default does nothing.
    var onOpen: (MeetingSlot<Course>, Int, Date) -> Void = { _, _, _ in }

    /// What to do when a "Not yet scheduled" chip is tapped. Phase 5b opens
    /// the class form so you can add its times.
    var onSchedule: (Course) -> Void = { _ in }

    /// How tall one hour is, in points. The web uses 62 on a page of its own;
    /// inside the Today card the grid has to fit a phone, so it's tighter.
    private let hourHeight: CGFloat = 36
    /// The width of the hour numbers' column on the left.
    private let gutter: CGFloat = 26

    var body: some View {
        // Work out everything the grid needs once per redraw.
        let dates = weekDates(now, weekOffset)
        // "Today" markers only belong on the current week.
        let todayCol: Int? = weekOffset == 0 ? dayIndex(of: now) : nil
        // Per day, because a term can start or end mid-week.
        let inTerm = dates.map { isWithinTerm(termStart, termEnd, $0) }
        let slots = expandClassMeetings(courses)
        let unscheduled = courses.filter { isUnscheduled($0) }
        let hours = gridHours(slots.map(\.meeting))
        let brand = Theme.brand(accent)

        VStack(alignment: .leading, spacing: 10) {
            header(dates, brand)

            // The whole week is outside the semester: say so once, rather
            // than leave an empty grid that looks broken.
            if !inTerm.contains(true) && !courses.isEmpty {
                outOfTermNote(brand)
            }

            dayHeader(dates, todayCol, brand)
            plot(hours, slots, dates, inTerm, todayCol, brand)

            if !unscheduled.isEmpty {
                notScheduled(unscheduled, brand)
            }
        }
    }

    // MARK: - Heading

    /// "OCT 19 – 25" over "This Week", with the previous/next arrows.
    private func header(_ dates: [Date], _ brand: Color) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text(weekRangeLabel(dates))
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted2)
                Text(weekTitle(weekOffset))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            arrow("chevron.left", "Previous week", brand) { weekOffset -= 1 }
            arrow("chevron.right", "Next week", brand) { weekOffset += 1 }
        }
        .padding(.horizontal, 4)
    }

    /// One round arrow button. `@escaping` marks a closure that's kept and
    /// run later (when the button is tapped), not straight away.
    private func arrow(_ symbol: String, _ label: String, _ brand: Color,
                       _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(brand)
                .frame(width: 38, height: 38)
                .background(Theme.card, in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// "This week is outside your semester (Sep 1 – Dec 15), nothing is timetabled."
    private func outOfTermNote(_ brand: Color) -> some View {
        let range = termRangeLabel(termStart, termEnd).map { " (\($0))" } ?? ""
        return Text("This week is outside your semester\(range), nothing is timetabled.")
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(brand.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// MON 19, TUE 20 ... with today's date in a brand circle.
    private func dayHeader(_ dates: [Date], _ todayCol: Int?, _ brand: Color) -> some View {
        let names = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        return HStack(spacing: 0) {
            // An empty slot the width of the hour column, so the days line up.
            Color.clear.frame(width: gutter, height: 1)
            ForEach(0..<7, id: \.self) { col in
                // A `let` inside a ForEach's closure: worked out once per column.
                let isToday = col == todayCol
                VStack(spacing: 3) {
                    Text(names[col])
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(isToday ? brand : Theme.faint)
                    Text("\(Calendar.autoupdatingCurrent.component(.day, from: dates[col]))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isToday ? Color.white : Theme.muted)
                        .frame(width: 26, height: 26)
                        .background(isToday ? brand : Color.clear, in: Circle())
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - The plot

    /// Minutes from midnight -> points down from the top of the plot. `top` is
    /// the first hour line in minutes (480 for 8 AM). The web's `y(mins)`.
    private func y(_ mins: Int, _ top: Int) -> CGFloat {
        CGFloat(mins - top) / 60 * hourHeight
    }

    /// The timetable itself: hour numbers on the left, then seven columns.
    /// Everything inside is placed by numbers, like absolute positioning in
    /// CSS: a `ZStack` piles its children on top of each other, all starting
    /// at its top edge, and `.offset(y:)` slides each one down to its time.
    /// An offset moves what you see without moving anything else, so the
    /// blocks can't push each other around.
    private func plot(_ hours: ClosedRange<Int>, _ slots: [MeetingSlot<Course>],
                      _ dates: [Date], _ inTerm: [Bool], _ todayCol: Int?,
                      _ brand: Color) -> some View {
        let top = hours.lowerBound * 60
        let height = CGFloat(hours.count - 1) * hourHeight
        let nowMin = minuteOfDay(now)
        // The now line only shows on the current week, inside the drawn hours.
        let showNow = todayCol != nil && nowMin >= top && nowMin <= hours.upperBound * 60

        return HStack(alignment: .top, spacing: 0) {
            // The hour numbers. `Array(hours)` turns 8...17 into [8, 9, ... 17].
            // Each label is lifted half its height so it sits on its line.
            ZStack(alignment: .topTrailing) {
                ForEach(Array(hours), id: \.self) { h in
                    Text(hourLabel(h))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.faint)
                        .offset(y: y(h * 60, top) - 6)
                }
            }
            .padding(.trailing, 6)
            .frame(width: gutter, height: height, alignment: .topTrailing)

            ZStack(alignment: .topLeading) {
                // A hairline at every hour, across all seven days.
                ForEach(Array(hours), id: \.self) { h in
                    Rectangle()
                        .fill(Theme.line)
                        .frame(height: 1)
                        .offset(y: y(h * 60, top))
                }

                // The seven day columns, side by side.
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        column(col, slots, dates[col], inTerm[col], col == todayCol, top, brand)
                    }
                }

                // Now: a coral line with a dot at its left end.
                if showNow {
                    Rectangle()
                        .fill(Theme.nowLine)
                        .frame(height: 2)
                        .offset(y: y(nowMin, top) - 1)
                    Circle()
                        .fill(Theme.nowLine)
                        .frame(width: 7, height: 7)
                        .offset(x: -3, y: y(nowMin, top) - 3.5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height, alignment: .top)
        }
        // The labels and the dot poke a few points outside the plot; keep
        // them from being clipped and give the last label room.
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    /// One day's column: a faint wash if it's today, then its class blocks.
    private func column(_ col: Int, _ slots: [MeetingSlot<Course>], _ date: Date,
                        _ inTerm: Bool, _ isToday: Bool, _ top: Int,
                        _ brand: Color) -> some View {
        // A day outside the semester has nothing on it.
        let daySlots = inTerm ? slots.filter { $0.meeting.days.contains(col) } : []
        return ZStack(alignment: .top) {
            Rectangle().fill(isToday ? brand.opacity(0.06) : Color.clear)
            // MeetingSlot is Identifiable, so ForEach can use it directly.
            ForEach(daySlots) { slot in
                block(slot, col, date, top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // A hairline between days (not before Monday).
        .overlay(alignment: .leading) {
            if col > 0 {
                Rectangle().fill(Theme.line).frame(width: 1)
            }
        }
    }

    /// One class block: short name and start time on the class's soft color,
    /// with a stripe of its dot color down the left. `ClassBlock` on the web.
    private func block(_ slot: MeetingSlot<Course>, _ col: Int, _ date: Date, _ top: Int) -> some View {
        let course = slot.course
        let meeting = slot.meeting
        // At least 30 points tall, so even a short class has room for its name.
        let height = max(y(meeting.end, top) - y(meeting.start, top), 30)

        return Button {
            onOpen(slot, col, date)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(course.short)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.subjectInk(course.color))
                    .lineLimit(2)
                Text(fmtClock(meeting.start))
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.subjectSub(course.color))
            }
            .padding(.leading, 6)
            .padding(.trailing, 2)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: height, alignment: .topLeading)
            .background(Theme.subjectSoft(course.color))
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.subject(course.color)).frame(width: 3)
            }
            // Clipping last trims the stripe and any text that doesn't fit
            // to the block's rounded shape.
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 2)
        .offset(y: y(meeting.start, top))
        .accessibilityLabel("\(course.name), \(fmtTime(meeting.start))")
    }

    // MARK: - Not yet scheduled

    /// Classes added before their times were known never land on the grid, so
    /// they're listed here instead. Tapping one opens it to add times (5b).
    private func notScheduled(_ list: [Course], _ brand: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOT YET SCHEDULED")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
            // Sideways scrolling, because a row of names can be wider than a phone.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(list) { course in
                        Button(course.name) { onSchedule(course) }
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(brand)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(brand.opacity(0.16), in: Capsule())
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(brand.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
