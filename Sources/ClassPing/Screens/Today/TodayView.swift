//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Today/TodayView.swift
//  Phase:   6b (your work and your classes), after 6a (the picked day),
//           5a (the week) and 5b (class details); changed in 7c (the
//           just-ended banner) and 13a (Import my schedule)
//  Ports:   app/home/page.tsx (the greeting, the quote, the just-ended
//           banner, the picked day's classes, every "nothing here" message,
//           the term glance, the assignments and My Classes) and
//           app/week/page.tsx (the week, folded into Today)
//
//  Summary: The Today tab. A greeting, then the week: folded, it's a strip of
//           seven days you can pick from; tap the calendar button (or pull the
//           handle) and it opens into the full timetable. Below it, the quote
//           banner, a "just finished" banner for half an hour after a class,
//           the picked day's classes, and then your term at a glance, your
//           next assignments and your classes, with Edit and Delete. Before
//           your first class, "Skip the typing" offers the import (13a).
//

import SwiftUI

/// One presentation at a time: a tapped meeting's details, a class's editor,
/// the form for a new class, or the import. Each case carries what its sheet needs.
enum TodaySheet: Identifiable {
    case meeting(OpenedMeeting)
    case editCourse(Course)
    case newCourse                    // NEW in Phase 6a: "Add a class manually"
    case importSchedule               // NEW in Phase 13a: "Import my schedule"

    var id: String {
        switch self {
        case .meeting(let opened):
            "meeting-\(opened.courseID)-\(opened.meetingID)-\(dayOf(opened.date))"
        case .editCourse(let course):
            "course-\(course.id)"
        case .newCourse:              // NEW in Phase 6a
            "new-course"
        case .importSchedule:         // NEW in Phase 13a
            "import"
        }
    }
}

/// The days' full English names, Monday first. `DAY_NAMES` in
/// app/home/page.tsx, for "View Thursday's schedule" and the title.
// NEW in Phase 6a
private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

struct TodayView: View {
    @Binding var tabBarCompact: Bool
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The selected tab, owned by RootView. A binding, so "View all" in the
    /// assignments can switch to the Tasks tab from in here.
    // NEW in Phase 6b
    @Binding var tab: MainTab

    // MARK: Screen state
    // None of this is saved: Today always opens on this week, folded,
    // with today picked.

    /// True when the week is open as the full grid, false when it's the strip.
    @State private var weekOpen = false
    /// Which week the strip and grid show: 0 = this week, 1 = next, -1 = last.
    @State private var weekOffset = 0
    /// The day picked in the strip, as local midnight. Starts on today.
    @State private var selectedDay = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    /// The sheet currently presented, or nil when none is open.
    @State private var sheet: TodaySheet?
    /// NEW in Phase 7c: the class whose just-ended banner you closed with ×.
    /// The web's `promptDismissed`. Only that class: a later one still shows.
    @State private var dismissedBanner: UUID?

    var body: some View {
        // `TimelineView` redraws what's inside it on a schedule. `.everyMinute`
        // fires at the start of each minute and hands over the time as
        // `context.date`, so the Now tag moves on and "today" rolls over at
        // midnight without a timer of our own. (The web uses `useNow()`.)
        TimelineView(.everyMinute) { context in
            let now = context.date
            let accent = store.profile.accent
            // The classes on this term's timetable: not deleted, not archived.
            // `activeClasses` in lib/store.tsx.
            let courses = store.activeCourses

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Class deletion and Undo save here too. Report a failed
                    // write even if deleting the last class shows first run.
                    if store.lastSaveFailed {
                        Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                            .font(.footnote)
                            .foregroundStyle(Theme.dangerInk)
                    }

                    Text(greeting(now))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted2)

                    weekCard(courses, now, accent)

                    // NEW in Phase 6a: the quote, then the picked day. Before
                    // the first class there is nothing to show for any day, so
                    // the setup steps take the day's place (the web's isFirstRun).
                    QuoteBanner(now: now)
                    if courses.isEmpty {
                        firstRun(accent)
                    } else {
                        daySection(courses, now, accent)

                        // NEW in Phase 6b: the lists under the day
                        // (TodaySections.swift). Like the web, they wait
                        // until there's a first class.
                        TermGlance(now: now)
                            .padding(.top, 8)
                        AssignmentsPreview(now: now, onViewAll: { tab = .tasks })
                            .padding(.top, 8)
                        MyClassesSection(onAdd: { sheet = .newCourse },
                                         onEdit: { course in sheet = .editCourse(course) })
                            .padding(.top, 8)
                    }
                }
                .padding(16)
                .padding(.bottom, 120)
            }
            .onScrollPhaseChange { _, phase in
                tabBarCompact = phase.isScrolling
            }
            // Browsing weeks keeps the picked weekday inside the visible week.
            .onChange(of: weekOffset) { _, offset in
                selectedDay = weekDates(now, offset)[dayIndex(of: selectedDay)]
            }
            // Keep following today across midnight until another day is picked.
            .onChange(of: Calendar.autoupdatingCurrent.startOfDay(for: now)) { previous, current in
                if weekOffset == 0 && selectedDay == previous {
                    selectedDay = current
                }
            }
        }
        .background(Theme.canvas)
        // NEW in Phase 6b: the Undo bar after deleting a class (or an
        // assignment from its detail screen), the same one Tasks uses.
        .undoBar()
        // Where a tapped assignment goes, as on the Tasks tab.
        .navigationDestination(for: AssignmentLink.self) { link in
            AssignmentDetailView(assignmentID: link.id)
        }
        // CHANGED in Phase 6a: "Today", or the picked day's name, like the
        // web's heading.
        .navigationTitle(Calendar.autoupdatingCurrent.isDateInToday(selectedDay)
                         ? "Today" : dayNames[dayIndex(of: selectedDay)])
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
            case .newCourse:          // NEW in Phase 6a
                NavigationStack {
                    CourseFormView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { sheet = nil }
                            }
                        }
                }
            case .importSchedule:     // NEW in Phase 13a
                ImportSheet()
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
    // NEW in Phase 6a: replaces the one-line day card from Phase 5a.

    /// The picked day: its class cards, then whichever message explains an
    /// empty day, then the way on to the next day. The middle of the web's
    /// home page. `@ViewBuilder` lets one function return different views
    /// depending on the `if`s, and allows the `let`s at the top.
    @ViewBuilder
    private func daySection(_ courses: [Course], _ now: Date, _ accent: Profile.Accent) -> some View {
        let day = selectedDay
        let col = dayIndex(of: day)
        let start = store.profile.termStart
        let end = store.profile.termEnd
        let isToday = Calendar.autoupdatingCurrent.isDate(day, inSameDayAs: now)
        let dayName = dayNames[col]

        // A timetable only exists inside its semester. Outside it, nothing is
        // listed and the screen says so instead of "you're free".
        let inTerm = isWithinTerm(start, end, day)
        let slots = expandClassMeetings(courses)
        // This day's meetings, earliest first.
        let dayClasses = inTerm
            ? slots.filter { $0.meeting.days.contains(col) }.sorted { $0.meeting.start < $1.meeting.start }
            : []

        // "You're all free this week!" only once you've looked six or more
        // days ahead and nothing in the picked day's week falls in the term.
        // (The web's `checkedAll`: an empty day alone doesn't mean a free week.)
        let dates = weekDates(day, 0)
        let weekHasClasses = slots.contains { slot in
            slot.meeting.days.contains { d in
                dates.indices.contains(d) && isWithinTerm(start, end, dates[d])
            }
        }
        let checkedAll = daysAhead(of: now) >= 6 && dayClasses.isEmpty && !weekHasClasses

        // Today gets Now / Done tags; any other day gets -1, which turns them off.
        let nowMin = isToday ? minuteOfDay(now) : -1
        let nextName = dayNames[(col + 1) % 7]

        // NEW in Phase 7c: a class that finished in the last half hour gets a
        // banner asking about homework, above the day's classes. Today only,
        // inside the term, and not once you've closed it for that class.
        if isToday && inTerm, let ended = justEnded(courses, now: now),
           dismissedBanner != ended.course.id {
            justEndedBanner(ended.course, accent)
        }

        // The classes, one card each. ForEach gives every card its slot's id,
        // which is how each ClassCard keeps its own open/folded state.
        if !dayClasses.isEmpty {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(dayClasses) { slot in
                    ClassCard(slot: slot, nowMin: nowMin)
                }
            }
            // A recurring meeting keeps its slot id across dates. Reset the
            // cards for a newly picked day so they always start expanded.
            .id(dayOf(day))
        }

        // At most one message: outside the term, a free day, or a free week.
        if !inTerm {
            let label = termRangeLabel(start, end)
            emptyState(emoji: "📅", title: "Outside your semester",
                       message: label.map { "Your term runs \($0), so nothing is timetabled for \(isToday ? "today" : dayName)." }
                           ?? "Nothing is timetabled for this date.")
        } else if checkedAll {
            emptyState(emoji: "🎉", title: "You're all free this week!",
                       message: "No classes scheduled this week. Enjoy your time!")
            Button {
                showDay(Calendar.autoupdatingCurrent.startOfDay(for: now), now)
            } label: {
                Text("Back to Today")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        } else if dayClasses.isEmpty {
            emptyState(emoji: "🌿", title: "Looks like you're free!",
                       message: isToday ? "Nothing scheduled for today." : "Nothing on \(dayName).")
            Button {
                showDay(scheduleDate(day, 1), now)
            } label: {
                HStack(spacing: 8) {
                    Text("View \(nextName)'s schedule")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(Theme.brandGradient(accent), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: Theme.brand(accent).opacity(0.32), radius: 12, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }

        // On a day with classes, or outside the term, a quieter way on.
        if !dayClasses.isEmpty || !inTerm {
            Button {
                showDay(scheduleDate(day, 1), now)
            } label: {
                HStack {
                    Text("View \(nextName)'s schedule")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(Theme.brand(accent))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.brand(accent).opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.brand(accent).opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    /// "Calculus III just finished · Did it come with an assignment?", with
    /// Log it (opens the post-class prompt) and × (hides it for this class).
    /// The just-ended banner in app/home/page.tsx. NEW in Phase 7c
    private func justEndedBanner(_ course: Course, _ accent: Profile.Accent) -> some View {
        HStack(spacing: 12) {
            Text("✍️")
                .font(.system(size: 17))
                .frame(width: 38, height: 38)
                .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(course.name) just finished")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("Did it come with an assignment?")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Opens the prompt the same way a tapped notification does: by
            // leaving a route in the store for RootView to take.
            Button {
                store.route = .postClass(course.id)
            } label: {
                Text("Log it")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Theme.brand(accent), in: Capsule())
                    // The pill stays small; the tap area is 44 points tall.
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                dismissedBanner = course.id
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.hint)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(Theme.brand(accent).opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Theme.brand(accent).opacity(0.14), lineWidth: 1))
    }

    /// The big emoji tile, a heading and a line of explanation, centred.
    /// The web repeats this block for each of its three messages.
    private func emptyState(emoji: String, title: String, message: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 38))
                .frame(width: 80, height: 80)
                .background(Theme.brandSoft(store.profile.accent),
                            in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.bottom, 14)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 10)
    }

    // MARK: - First run
    // NEW in Phase 6a

    /// Before the first class: one job, get a class in. The web's first-run
    /// card: "Skip the typing" leads with Import my schedule, and the manual
    /// route stays one tap away under it, because for three classes typing
    /// them in is genuinely faster. Then the three steps.
    // CHANGED in Phase 13a: the card, with the import
    private func firstRun(_ accent: Profile.Accent) -> some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Skip the typing")
                    .font(.system(size: 22, weight: .semibold))
                Text("Your school already has your timetable. Bring it over and ClassPing takes it from there, your week, your deadlines, and a nudge before each one.")
                    .font(.system(size: 14))
                    .opacity(0.85)
                    .fixedSize(horizontal: false, vertical: true)

                // White on the gradient in both themes, as on the web.
                Button {
                    sheet = .importSchedule
                } label: {
                    Text("Import my schedule")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.brand(accent))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)

                Button {
                    sheet = .newCourse
                } label: {
                    Text("Add a class manually")
                        .font(.system(size: 14.5, weight: .semibold))
                        .opacity(0.9)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.brandGradient(accent), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Theme.brand(accent).opacity(0.3), radius: 10, x: 0, y: 6)
            .padding(.bottom, 6)

            onboardStep(1, "Import or add your classes",
                        "Drop in your school's calendar file, or type a class in, about 20 seconds each.", accent)
            // The web says "on the Week tab"; on the phone the week lives
            // behind Today's calendar button (D-19).
            onboardStep(2, "Your week fills in",
                        "See today at a glance, and the whole week from the calendar button.", accent)
            onboardStep(3, "Get reminded",
                        "A heads-up before class starts, and before work is due.", accent)
        }
    }

    /// One numbered step. `OnboardStep` in app/home/page.tsx.
    private func onboardStep(_ n: Int, _ title: String, _ body: String, _ accent: Profile.Accent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.brand(accent))
                .frame(width: 26, height: 26)
                .background(Theme.brandSoft(accent), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardStyle()
    }

    // MARK: - Moving between days
    // NEW in Phase 6a

    /// Picks `day` and moves the strip to the week that holds it, so "View
    /// Monday's schedule" on a Sunday lands on next week's Monday.
    private func showDay(_ day: Date, _ now: Date) {
        // Whole weeks between this week's Monday and the day, rounded down,
        // so a day in last week is -1 and not 0.
        let monday = weekDates(now, 0)[0]
        let days = Calendar.autoupdatingCurrent.dateComponents([.day], from: monday, to: day).day ?? 0
        selectedDay = day
        weekOffset = Int((Double(days) / 7).rounded(.down))
    }

    /// How many days after today the picked day is (0 = today, -1 = yesterday).
    /// The web's `offset`. Counted in calendar days, so a daylight-saving
    /// change can't make it off by one.
    private func daysAhead(of now: Date) -> Int {
        let today = Calendar.autoupdatingCurrent.startOfDay(for: now)
        return Calendar.autoupdatingCurrent.dateComponents([.day], from: today, to: selectedDay).day ?? 0
    }

    /// "Good morning, Kelvin 👋". The web's `greeting(hour)` plus the first
    /// part of your username; just the greeting until you've set a name.
    // CHANGED in Phase 6a: the wave, as on the web.
    private func greeting(_ now: Date) -> String {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: now)
        let hello = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        // "kelvin.m" -> "kelvin": the web splits on dots, spaces, _ and -.
        let first = store.profile.username
            .split(whereSeparator: { $0.isWhitespace || "._-".contains($0) })
            .first.map(String.init) ?? ""
        return first.isEmpty ? "\(hello) 👋" : "\(hello), \(first) 👋"
    }
}
