//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentsView.swift
//  Phase:   4b (the Tasks screen)  [replaces the Phase 2 list at Sources/ClassPing/AssignmentsView.swift]
//  Ports:   app/tasks/page.tsx (the list, Open/Done, groups, rows),
//           components/TaskFilterBar.tsx (`useTaskViewPrefs`, the remembered
//           choices)
//
//  Summary: The Tasks tab. Open or Done work, filtered, grouped by urgency
//           (Overdue, Today, Upcoming, No deadline) and earliest first. The
//           circle completes a task; the rest of the row opens its detail.
//           After a delete, the Undo bar (Components/UndoBar.swift) waits for
//           8 seconds.
//

import SwiftUI

/// The value pushed when a row is tapped. A tiny wrapper instead of a bare
/// UUID, so a later screen that pushes some other UUID can never land on the
/// assignment detail by mistake.
struct AssignmentLink: Hashable {
    let id: UUID
}

private enum TaskLayout: String {
    case widgets
    case list
}

struct AssignmentsView: View {
    @Binding var tabBarCompact: Bool
    @Environment(Store.self) private var store

    // MARK: Remembered choices
    // `@AppStorage("key")` is a property saved in UserDefaults, the phone's
    // small key-value store for preferences (the web keeps these in
    // localStorage). It survives relaunches, and the view redraws when it
    // changes. It only holds simple values, so the filters are four of them.
    @AppStorage("tasks.tab") private var tabRaw = "open"
    @AppStorage("tasks.subject") private var subjectRaw = ""        // a class id, or ""
    @AppStorage("tasks.kind") private var kindRaw = ""              // a kind name, or ""
    @AppStorage("tasks.includeArchived") private var includeArchived = true
    @AppStorage("tasks.layout") private var layoutRaw = TaskLayout.widgets.rawValue

    /// Whether the filter panel is open. Not remembered, like the web.
    @State private var filtersOpen = false

    var body: some View {
        // Read everything once per redraw. `now` is the moment of this redraw;
        // the groups refresh whenever the screen does (Phase 6 adds a ticking clock).
        let now = Date.now
        let accent = store.profile.accent
        let prefs = currentPrefs
        let all = store.liveAssignments

        // Filter, split into open and done, then pick the tab's half.
        // `filterTasks` asks the store whether each class is archived.
        let visible = filterTasks(all, prefs.filters, isArchived: { id in
            store.course(id)?.archived ?? false
        })
        let list = visible.filter { $0.done == (prefs.tab == .done) }
        let groups = groupTasks(list, now)
        // "3 of 12": the 12 is every task in this tab before filtering.
        let total = all.filter { $0.done == (prefs.tab == .done) }.count
        // Only classes that have work get a filter chip.
        let filterable = store.courses.filter { course in
            course.deletedAt == nil && all.contains(where: { $0.courseID == course.id })
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                // Never hide a failed save (kept from Phase 1).
                if store.lastSaveFailed {
                    Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.dangerInk)
                }

                // Open / Done. The binding reads the saved tab and writes it back.
                Picker("Show", selection: tabBinding) {
                    Text("Open").tag(TaskTab.open)
                    Text("Done").tag(TaskTab.done)
                }
                .pickerStyle(.segmented)

                Picker("Task layout", selection: $layoutRaw) {
                    Label("Widgets", systemImage: "square.grid.2x2")
                        .tag(TaskLayout.widgets.rawValue)
                    Label("List", systemImage: "list.bullet")
                        .tag(TaskLayout.list.rawValue)
                }
                .pickerStyle(.segmented)

                TaskFilterBar(filters: filtersBinding, open: $filtersOpen,
                              courses: filterable, showing: list.count, total: total,
                              accent: accent)

                // Nothing to show: say why, in the web app's words.
                if list.isEmpty {
                    Text(emptyMessage(prefs))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }

                // One heading per non-empty group, then its rows.
                ForEach(groups) { group in
                    header(group.id, group.label, group.tasks.count, accent)
                    if layoutRaw == TaskLayout.widgets.rawValue {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                            GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(group.tasks) { assignment in
                                taskWidget(assignment, now)
                            }
                        }
                    } else {
                        ForEach(group.tasks) { assignment in
                            row(assignment, now)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .onScrollPhaseChange { _, phase in
            tabBarCompact = phase.isScrolling
        }
        .background(Theme.canvas)
        // Where a tapped row goes. The detail looks the assignment up by id, so
        // it always shows the latest version, even right after an edit.
        .navigationDestination(for: AssignmentLink.self) { link in
            AssignmentDetailView(assignmentID: link.id)
        }
        // The Undo bar, shared with Today: see Components/UndoBar.swift.
        .undoBar()
    }

    // MARK: - Preferences as bindings

    /// The four saved values, cleaned up by the ported `normalizeViewPrefs`.
    private var currentPrefs: TaskViewPrefs {
        normalizeViewPrefs(tab: tabRaw, subject: subjectRaw, kind: kindRaw,
                           includeArchived: includeArchived)
    }

    /// A hand-made binding: `get` reads the saved tab, `set` saves a new one.
    /// `Binding(get:set:)` is how you give a Picker a two-way connection to a
    /// value that is really stored in some other shape (here, text).
    private var tabBinding: Binding<TaskTab> {
        Binding(get: { currentPrefs.tab },
                set: { tabRaw = $0.rawValue })
    }

    /// The same idea for the filters: the bar sees one TaskFilters value, and
    /// each change is split back into the three saved values.
    private var filtersBinding: Binding<TaskFilters> {
        Binding(get: { currentPrefs.filters },
                set: { f in
                    subjectRaw = f.subject?.uuidString ?? ""
                    kindRaw = f.kind ?? ""
                    includeArchived = f.includeArchived
                })
    }

    // MARK: - Pieces

    /// The empty-list message, word for word from the web page.
    private func emptyMessage(_ prefs: TaskViewPrefs) -> String {
        if prefs.filters.activeCount > 0 { return "Nothing matches these filters." }
        return prefs.tab == .open ? "🎉 All caught up, no open assignments." : "Nothing completed yet."
    }

    /// A group heading: "OVERDUE 2". Overdue in the danger ink, Today in the
    /// deep brand color, the rest faint, as on the web.
    private func header(_ bucket: DueBucket, _ label: String, _ count: Int,
                        _ accent: Profile.Accent) -> some View {
        let color: Color = switch bucket {
        case .overdue: Theme.dangerInk
        case .today:   Theme.brandDeep(accent)
        default:       Theme.faint
        }
        return HStack(spacing: 6) {
            Text(label.uppercased())
                .tracking(1.4)
                .foregroundStyle(color)
            Text("\(count)")
                .foregroundStyle(Theme.faint)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    /// One task. `TaskRow` in app/tasks/page.tsx. The circle is its own button
    /// (complete / reopen); the rest of the card is a NavigationLink to the
    /// detail. On the web the row unfolds in place first; on a phone the
    /// detail screen does that job.
    private func row(_ a: Assignment, _ now: Date) -> some View {
        let course = store.course(a.courseID)
        let due = dueLabel(a.deadline, now)

        return HStack(alignment: .top, spacing: 12) {
            // The completion circle: filled green with a tick when done.
            Button {
                store.toggleAssignment(a.id)
            } label: {
                ZStack {
                    Circle()
                        .fill(a.done ? Theme.good : Color.clear)
                    Circle()
                        .strokeBorder(a.done ? Color.clear : Theme.lineStrong, lineWidth: 2)
                    if a.done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(a.done ? "Mark as open" : "Complete")

            // Everything else opens the detail.
            NavigationLink(value: AssignmentLink(id: a.id)) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        // Title, with an Exam or Quiz badge on open work.
                        HStack(spacing: 6) {
                            if !a.done { badge(a.kind) }
                            Text(a.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(a.done ? Theme.muted : Theme.ink)
                                .strikethrough(a.done)
                                .multilineTextAlignment(.leading)
                        }
                        // The class dot and name, plus 📝 when it has notes.
                        HStack(spacing: 6) {
                            Circle()
                                .fill(a.done ? Theme.hint : course.map { Theme.subject($0.color) } ?? Theme.lineStrong)
                                .frame(width: 8, height: 8)
                            Text(course?.name ?? "Inbox")
                                .font(.system(size: 13))
                                .foregroundStyle(a.done ? Theme.hint : Theme.muted)
                                .strikethrough(a.done)
                                .lineLimit(1)
                            if !(a.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("· 📝").font(.system(size: 13)).foregroundStyle(Theme.hint)
                            }
                        }
                    }
                    Spacer(minLength: 4)
                    // The deadline pill, only on open work. Red when urgent.
                    if !a.done {
                        Text(due.text)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundStyle(due.urgent ? Theme.dangerInk : Theme.muted)
                            .background(due.urgent ? Theme.dangerSoft : Theme.surface2, in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.hint)
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .cardStyle()
        .opacity(a.done ? 0.7 : 1)
    }

    /// A compact square task card for the widget layout. The check button
    /// stays separate from the detail link, matching the list behavior.
    private func taskWidget(_ a: Assignment, _ now: Date) -> some View {
        let course = store.course(a.courseID)
        let due = dueLabel(a.deadline, now)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                if !a.done { badge(a.kind) }
                else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.good)
                }
                Spacer(minLength: 0)
                Button {
                    store.toggleAssignment(a.id)
                } label: {
                    Image(systemName: a.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(a.done ? Theme.good : Theme.lineStrong)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(a.done ? "Mark as open" : "Complete")
            }

            NavigationLink(value: AssignmentLink(id: a.id)) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(a.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(a.done ? Theme.muted : Theme.ink)
                        .strikethrough(a.done)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(a.done ? Theme.hint : course.map { Theme.subject($0.color) } ?? Theme.lineStrong)
                            .frame(width: 7, height: 7)
                        Text(course?.name ?? "Inbox")
                            .font(.system(size: 11))
                            .foregroundStyle(a.done ? Theme.hint : Theme.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text(a.done ? "Completed" : due.text)
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .foregroundStyle(a.done ? Theme.muted : due.urgent ? Theme.dangerInk : Theme.muted)
                        .background(a.done ? Theme.surface2 : due.urgent ? Theme.dangerSoft : Theme.surface2,
                                    in: Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .cardStyle()
        .opacity(a.done ? 0.7 : 1)
    }

    /// The small kind chip. Only exams and quizzes wear one; assignments are
    /// the unmarked default. `typeBadge` in app/tasks/page.tsx.
    @ViewBuilder
    private func badge(_ kind: Assignment.Kind) -> some View {
        if kind == .exam || kind == .quiz {
            Text(kind.label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .foregroundStyle(kind == .exam ? Theme.warnInk : Theme.infoInk)
                .background(kind == .exam ? Theme.warnSoft : Theme.infoSoft, in: Capsule())
        }
    }
}
