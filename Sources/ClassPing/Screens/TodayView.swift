//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/TodayView.swift
//  Phase:   5b (class details and editing), following the 5a week redesign
//  Ports:   app/home/page.tsx (the greeting and day picking) and
//           app/week/page.tsx (the week, folded into Today)
//
//  Summary: The Today tab. A greeting, then the week: folded, it's a strip of
//           seven days you can pick from; tap the calendar button (or pull the
//           handle) and it opens into the full timetable. Phase 6 adds the
//           picked day's classes, priorities and planned work below.
//

import SwiftUI

/// One presentation at a time: a tapped meeting's details or an unscheduled
/// class's editor. Each case carries the information its sheet needs.
enum TodaySheet: Identifiable {
    case meeting(OpenedMeeting)
    case editCourse(Course)

    var id: String {
        switch self {
        case .meeting(let opened):
            "meeting-\(opened.courseID)-\(opened.meetingID)-\(dayOf(opened.date))"
        case .editCourse(let course):
            "course-\(course.id)"
        }
    }
}

struct TodayView: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Screen state
    // NEW in Phase 5a. None of this is saved: Today always opens on this
    // week, folded, with today picked.

    /// True when the week is open as the full grid, false when it's the strip.
    @State private var weekOpen = false
    /// Which week the strip and grid show: 0 = this week, 1 = next, -1 = last.
    @State private var weekOffset = 0
    /// The day picked in the strip, as local midnight. Starts on today.
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    /// The class sheet currently presented, or nil when none is open.
    @State private var sheet: TodaySheet?

    var body: some View {
        // `TimelineView` redraws what's inside it on a schedule. `.everyMinute`
        // fires at the start of each minute and hands over the time as
        // `context.date`, so the now line moves and "today" rolls over at
        // midnight without a timer of our own. (The web uses `useNow()`.)
        TimelineView(.everyMinute) { context in
            let now = context.date
            let accent = store.profile.accent
            // The classes on this term's timetable: not deleted, not archived.
            // `activeClasses` in lib/store.tsx, now shared by class screens.
            let courses = store.activeCourses

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(greeting(now))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted2)

                    weekCard(courses, now, accent)
                    dayCard(courses)
                }
                .padding(16)
            }
            // Browsing weeks keeps the picked weekday inside the visible week.
            .onChange(of: weekOffset) { _, offset in
                selectedDay = weekDates(now, offset)[dayIndex(of: selectedDay)]
            }
            // Keep following today across midnight until another day is picked.
            .onChange(of: Calendar.current.startOfDay(for: now)) { previous, current in
                if weekOffset == 0 && selectedDay == previous {
                    selectedDay = current
                }
            }
        }
        .background(Theme.canvas)
        .navigationTitle("Today")
        // The calendar button where the web's gear used to be (the gear's
        // job moved to the Profile tab). It opens and folds the week.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleWeek()
                } label: {
                    Image(systemName: weekOpen ? "calendar.circle.fill" : "calendar")
                }
                .accessibilityLabel(weekOpen ? "Fold the week away" : "Show the whole week")
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .meeting(let opened):
                CourseSheet(opened: opened)
            case .editCourse(let course):
                NavigationStack {
                    CourseFormView(editing: course)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { sheet = nil }
                            }
                        }
                }
            }
        }
    }

    // MARK: - The week

    /// The card holding the week: the grid when open, the strip when folded,
    /// and the handle underneath either way.
    private func weekCard(_ courses: [Course], _ now: Date, _ accent: Profile.Accent) -> some View {
        let start = store.profile.termStart
        let end = store.profile.termEnd

        return VStack(spacing: 6) {
            // `$weekOffset` hands the child a binding: the strip and the grid
            // both read and change the same week.
            if weekOpen {
                WeekGrid(courses: courses, termStart: start, termEnd: end, now: now,
                         weekOffset: $weekOffset, accent: accent,
                         onOpen: { slot, day, date in
                             sheet = .meeting(OpenedMeeting(courseID: slot.course.id,
                                                            meetingID: slot.meeting.id,
                                                            day: day, date: date))
                         },
                         onSchedule: { course in
                             sheet = .editCourse(course)
                         })
                    .transition(.opacity)
            } else {
                WeekStrip(courses: courses, termStart: start, termEnd: end, now: now,
                          weekOffset: $weekOffset, selected: $selectedDay, accent: accent)
                    .transition(.opacity)
            }
            handle
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    /// The little bar under the week. Tap it, or drag it down to open and up
    /// to fold. `highPriorityGesture` means a drag that starts on the handle
    /// moves the week instead of scrolling the page.
    private var handle: some View {
        Capsule()
            .fill(Theme.lineStrong)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity, minHeight: 24)
            .contentShape(Rectangle())
            .onTapGesture { toggleWeek() }
            .highPriorityGesture(
                DragGesture(minimumDistance: 10).onEnded { drag in
                    // Down by 24 points or more opens; up by 24 or more folds.
                    if drag.translation.height > 24 && !weekOpen { toggleWeek() }
                    if drag.translation.height < -24 && weekOpen { toggleWeek() }
                }
            )
            // To VoiceOver this is a button with a clear name.
            .accessibilityElement()
            .accessibilityLabel(weekOpen ? "Fold the week away" : "Open the whole week")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { toggleWeek() }
    }

    /// Opens or folds the week. `withAnimation` animates every change the
    /// toggle causes: the card grows or shrinks smoothly, and the strip and
    /// grid cross-fade because each has `.transition(.opacity)`.
    private func toggleWeek() {
        withAnimation(reduceMotion ? nil : .snappy) {
            weekOpen.toggle()
        }
    }

    // MARK: - The picked day

    /// A one-line look at the day picked in the strip. Phase 6 replaces this
    /// card with that day's class cards, priorities and planned work.
    private func dayCard(_ courses: [Course]) -> some View {
        let col = dayIndex(of: selectedDay)
        let inTerm = isWithinTerm(store.profile.termStart, store.profile.termEnd, selectedDay)
        let count = inTerm
            ? expandClassMeetings(courses).filter { $0.meeting.days.contains(col) }.count
            : 0
        // "Wednesday", in the phone's language.
        let dayName = selectedDay.formatted(.dateTime.weekday(.wide))
        let headline = switch count {
        case 0: "No classes on \(dayName)"
        case 1: "\(dayName) · 1 class"
        default: "\(dayName) · \(count) classes"
        }

        return VStack(alignment: .leading, spacing: 6) {
            Text(headline)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Your classes, priorities and planned work for this day will appear here.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// "Good morning, Kelvin". The web's `greeting(hour)` plus the first part
    /// of your username; just the greeting until you've set a name.
    private func greeting(_ now: Date) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        let hello = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        // "kelvin.m" -> "kelvin": the web splits on dots, spaces, _ and -.
        let first = store.profile.username
            .split(whereSeparator: { $0.isWhitespace || "._-".contains($0) })
            .first.map(String.init) ?? ""
        return first.isEmpty ? hello : "\(hello), \(first)"
    }
}
