//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Today/TodaySections.swift
//  Phase:   6b (Today: your work and your classes)
//  Ports:   TermGlance and Stat, the Assignments section and the My Classes
//           section of app/home/page.tsx
//
//  Summary: The three blocks under the picked day on Today: three numbers
//           about your term, your next four open assignments, and your classes
//           with Edit and Delete. Deleting asks first, then the Undo bar can
//           bring the class back with all its work.
//

import SwiftUI

// MARK: - This term at a glance

/// "12 done · 3 this week · 5 days clear". `TermGlance` in app/home/page.tsx.
/// Hidden until you have any work: a row of zeroes on day one is just noise.
struct TermGlance: View {
    @Environment(Store.self) private var store
    /// The moment to count from, from Today's ticking clock.
    let now: Date

    var body: some View {
        let work = store.liveAssignments
        let accent = store.profile.accent

        // An `if` with no `else` in a body: with no work, nothing is drawn.
        if !work.isEmpty {
            let stats = termStats(work, now)
            HStack(spacing: 10) {
                stat(stats.completed, "done", Theme.ink)
                divider
                stat(stats.dueThisWeek, "this week",
                     stats.dueThisWeek > 0 ? Theme.brand(accent) : Theme.ink)
                divider
                // Overdue work takes the last slot when there is any; the
                // streak only shows while you're clear.
                if stats.overdue > 0 {
                    stat(stats.overdue, "overdue", Theme.dangerInk)
                } else {
                    stat(stats.streak, stats.streak == 1 ? "day clear" : "days clear", Theme.goodInk)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .cardStyle()
        }
    }

    /// One number with its label under it. `Stat` in app/home/page.tsx.
    private func stat(_ value: Int, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.muted2)
        }
        .frame(maxWidth: .infinity)
        // Read "5, days clear" as one item, not two.
        .accessibilityElement(children: .combine)
    }

    /// The thin line between two numbers.
    private var divider: some View {
        Rectangle()
            .fill(Theme.surface2)
            .frame(width: 1, height: 32)
    }
}

// MARK: - Assignments

/// Your four soonest open assignments, with a count and a way to the Tasks
/// tab. The Assignments section of app/home/page.tsx.
struct AssignmentsPreview: View {
    @Environment(Store.self) private var store
    let now: Date
    /// What "View all" does. Today hands in "switch to the Tasks tab".
    let onViewAll: () -> Void

    var body: some View {
        let accent = store.profile.accent
        // Open work, soonest due first. `byDeadline` keeps undated work at the
        // end, never mixed in with dated work (a product rule).
        let open = store.liveAssignments.filter { !$0.done }.sorted(by: byDeadline)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Assignments")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                // How many are open, in a coral bubble.
                if !open.isEmpty {
                    Text("\(open.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.subject(.coral), in: Capsule())
                }
                Spacer()
                Button(action: onViewAll) {
                    HStack(spacing: 4) {
                        Text("View all")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.brandSoft(accent), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if open.isEmpty {
                Text("🎉 No open assignments.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .cardStyle()
            } else {
                // `prefix(4)` takes the first four (or fewer); `Array(...)`
                // turns that slice back into a normal list for ForEach.
                ForEach(Array(open.prefix(4))) { assignment in
                    row(assignment, accent)
                }
            }
        }
    }

    /// One assignment. Tapping it opens its own detail screen, not the list:
    /// the web learned that landing on a list made you find it a second time.
    private func row(_ a: Assignment, _ accent: Profile.Accent) -> some View {
        let course = store.course(a.courseID)
        let due = dueLabel(a.deadline, now)

        // `NavigationLink(value:)` pushes the detail; TodayView says what to
        // show for an AssignmentLink with `.navigationDestination`.
        return NavigationLink(value: AssignmentLink(id: a.id)) {
            HStack(spacing: 12) {
                // The class color, indigo for Inbox work like the web.
                Circle()
                    .fill(Theme.subject(course?.color ?? .indigo))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // Only exams get a badge here (the Tasks list also marks quizzes).
                        if a.kind == .exam {
                            Text("EXAM")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.warnInk)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.warnSoft, in: Capsule())
                        }
                        Text(a.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                    // The class name, or "-" for Inbox work, as on the web.
                    Text(course?.name ?? "-")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // The deadline pill: red when it's urgent, quiet otherwise.
                Text(due.text)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .foregroundStyle(due.urgent ? Theme.dangerInk : Theme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(due.urgent ? Theme.dangerSoft : Theme.brandSoft(accent), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - My Classes

/// Every class on this term's timetable, with Edit and Delete. The My Classes
/// section of app/home/page.tsx.
struct MyClassesSection: View {
    @Environment(Store.self) private var store
    /// What "Add" does, and what the pencil does. Today opens its sheets.
    let onAdd: () -> Void
    let onEdit: (Course) -> Void

    /// The class whose trash button was tapped, waiting for you to confirm.
    /// nil means no question is being asked.
    @State private var deleting: Course?

    var body: some View {
        let accent = store.profile.accent

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("My Classes")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.brandSoft(accent), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            // Archived classes stay out, like the week: `activeCourses`.
            ForEach(store.activeCourses) { course in
                row(course)
            }
        }
        // The "are you sure?" question, as an iOS action sheet. It shows
        // while `isPresented` is true; `presenting:` hands the class to the
        // buttons, so they act on the class you tapped even if the list
        // changes underneath. iOS adds the Cancel button by itself. The web
        // asks the same question inline, under the row.
        .confirmationDialog(deleting.map { "Delete “\($0.name)”?" } ?? "",
                            isPresented: confirmShown,
                            titleVisibility: .visible,
                            presenting: deleting) { course in
            Button("Delete", role: .destructive) {
                store.deleteCourse(course.id)
            }
        }
    }

    /// The dialog wants a true/false binding; the real state is `deleting`.
    /// `get` says "showing while a class is waiting", and when iOS closes the
    /// dialog (Cancel, Delete or a tap outside) `set` clears it.
    private var confirmShown: Binding<Bool> {
        Binding(get: { deleting != nil },
                set: { showing in
                    if !showing { deleting = nil }
                })
    }

    /// One class: its book, name and when it meets, then Edit and Delete.
    private func row(_ course: Course) -> some View {
        HStack(spacing: 12) {
            SubjectBook(color: course.color, short: course.short, compact: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                // "Mon/Wed 09:00–10:15 · Room 4", from Phase 5a.
                Text(meetingSummary(course))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            circleButton("pencil", Theme.muted, label: "Edit \(course.name)") {
                onEdit(course)
            }
            circleButton("trash", Theme.faint, label: "Delete \(course.name)") {
                deleting = course
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardStyle()
    }

    /// A small round icon button on the quiet surface. `action` is the code to
    /// run when it's tapped: a function passed in like any other value.
    /// `@escaping` is Swift's word for "this closure is kept and run later"
    /// (the Button holds on to it until you tap), and the compiler asks for it.
    private func circleButton(_ symbol: String, _ color: Color, label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(Theme.surface2, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
