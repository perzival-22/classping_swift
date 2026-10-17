//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Week/WeekStrip.swift
//  Phase:   5a (the new tab bar and the week)
//  Ports:   the day header of app/week/page.tsx, folded into Today (D-19);
//           the "Today · Wed, Oct 21" day pill on app/home/page.tsx
//
//  Summary: The folded week on Today: seven days in a row, today in a filled
//           circle, up to three colored dots per day for the classes that day.
//           Tapping a day picks it. Phase 6 shows that day's classes below.
//

import SwiftUI

struct WeekStrip: View {
    /// The classes to dot onto the days, already filtered to the live,
    /// unarchived ones by whoever shows the strip.
    let courses: [Course]
    /// The semester's ends ("yyyy-MM-dd"), so days outside it get no dots.
    let termStart: String?
    let termEnd: String?
    /// The moment this redraw is for, from Today's ticking clock.
    let now: Date
    /// Which week is showing (0 = this week). A `@Binding` because Today owns
    /// it and the grid shares it: browse to next week in the grid, fold it,
    /// and the strip is on next week too.
    @Binding var weekOffset: Int
    /// The day you picked, as local midnight. Also owned by Today.
    @Binding var selected: Date
    let accent: Profile.Accent

    /// One letter per column, Monday first.
    private let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let dates = weekDates(now, weekOffset)
        let slots = expandClassMeetings(courses)
        let brand = Theme.brand(accent)

        VStack(spacing: 8) {
            // The range on the left; on the right "This Week", or a way back
            // to it when you've browsed away in the grid.
            HStack {
                Text(weekRangeLabel(dates))
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted2)
                Spacer()
                if weekOffset == 0 {
                    Text("This Week")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(brand)
                } else {
                    Button("Back to this week") {
                        weekOffset = 0
                        selected = scheduleDate(now, 0)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(brand)
                }
            }
            .padding(.horizontal, 8)

            // The seven days. `0..<7` is Monday to Sunday; `id: \.self` tells
            // ForEach the numbers themselves tell the columns apart.
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { col in
                    dayButton(col, dates[col], dots(on: col, dates[col], slots), brand)
                }
            }
        }
    }

    /// The color of every class on one day, earliest first. Days outside the
    /// semester get none, the same rule the grid follows.
    private func dots(on col: Int, _ date: Date, _ slots: [MeetingSlot<Course>]) -> [SubjectColor] {
        guard isWithinTerm(termStart, termEnd, date) else { return [] }
        return slots.filter { $0.meeting.days.contains(col) }
            .sorted { $0.meeting.start < $1.meeting.start }
            .map { $0.course.color }        // swap each slot for its color
    }

    /// One day: its letter, its date in a circle, and the class dots.
    private func dayButton(_ col: Int, _ date: Date, _ dots: [SubjectColor], _ brand: Color) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDate(date, inSameDayAs: now)
        let isPicked = cal.isDate(date, inSameDayAs: selected)
        // At most three dots fit under a day. `prefix(3)` keeps the first three.
        let shown = Array(dots.prefix(3))

        return Button {
            selected = date
        } label: {
            VStack(spacing: 4) {
                Text(letters[col])
                    .font(.system(size: 11, weight: isToday ? .bold : .semibold))
                    .foregroundStyle(isToday ? brand : Theme.faint)

                // Today: a filled brand circle. A picked day that isn't today:
                // a brand ring. `.background` and `.overlay` take a view, and
                // an `if` inside them draws it only when the condition holds.
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 15, weight: isToday ? .bold : .semibold))
                    .foregroundStyle(isToday ? Color.white : Theme.muted)
                    .frame(width: 32, height: 32)
                    .background {
                        if isToday { Circle().fill(brand) }
                    }
                    .overlay {
                        if isPicked && !isToday { Circle().stroke(brand, lineWidth: 1.5) }
                    }

                // The dots, in a fixed-height row so days without classes
                // line up with the rest.
                HStack(spacing: 3) {
                    ForEach(shown.indices, id: \.self) { i in
                        Circle()
                            .fill(Theme.subject(shown[i]))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            // Makes the whole column tappable, not just the text and circles.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // VoiceOver hears "Wednesday, October 21, 3 classes" instead of "W 21".
        .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide).month(.wide).day())), \(classCount(dots.count))")
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    /// "no classes", "1 class", "4 classes", for VoiceOver.
    private func classCount(_ n: Int) -> String {
        switch n {
        case 0: "no classes"
        case 1: "1 class"
        default: "\(n) classes"
        }
    }
}
