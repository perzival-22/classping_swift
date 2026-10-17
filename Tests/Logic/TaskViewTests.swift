// TaskViewTests.swift: the Swift twin of lib/task-view.test.ts, plus cases for
// `dueLabel` and `longDeadline` (ported from lib/store.tsx, which has no tests
// of its own for them, so these pin the web code's behavior as read).
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

/// Local wall-clock Date in the runner's own zone, the zone the logic reads.
private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

/// `new Date("2026-09-07T12:00:00")` in the web test: local noon.
private let NOW = at(2026, 9, 7, 12)

private let c1 = UUID()
private let c2 = UUID()

/// A stand-in task, the `task({...})` helper in the web test.
private struct Item: TaskListable {
    var id = "x"
    var title = "Thing"
    var courseID: UUID? = c1
    var due: String? = "2026-09-10"
    var dueTime: String? = nil
    var kindName = "assignment"
}

@Suite struct TaskViewTests {

    // MARK: groupTasks

    @Test func splitsWorkIntoTheFourQuestions() {
        let groups = groupTasks([
            Item(id: "late", due: "2026-09-01"),
            Item(id: "today", due: "2026-09-07"),
            Item(id: "soon", due: "2026-09-09"),
            Item(id: "inbox", due: nil),
        ], NOW)
        #expect(groups.map(\.id) == [.overdue, .today, .upcoming, .none])
        #expect(groups.map { $0.tasks[0].id } == ["late", "today", "soon", "inbox"])
        #expect(groups.map(\.label) == ["Overdue", "Today", "Upcoming", "No deadline"])
    }

    @Test func neverShowsAnEmptyHeading() {
        let groups = groupTasks([Item(due: "2026-09-20")], NOW)
        #expect(groups.map(\.id) == [.upcoming])
    }

    @Test func ordersUpcomingSoonestFirst() {
        let groups = groupTasks([
            Item(id: "c", due: "2026-09-20"),
            Item(id: "a", due: "2026-09-08"),
            Item(id: "b", due: "2026-09-12"),
        ], NOW)
        #expect(groups[0].tasks.map(\.id) == ["a", "b", "c"])
    }

    @Test func ordersOverdueMostRecentFirst() {
        let groups = groupTasks([
            Item(id: "ancient", due: "2026-08-10"),
            Item(id: "yesterday", due: "2026-09-06"),
        ], NOW)
        #expect(groups[0].tasks.map(\.id) == ["yesterday", "ancient"])
    }

    @Test func usesTheTimeOfDayToDecideOverdue() {
        let groups = groupTasks([
            Item(id: "missed", due: "2026-09-07", dueTime: "09:00"),
            Item(id: "tonight", due: "2026-09-07", dueTime: "23:30"),
        ], NOW)
        #expect(groups.first(where: { $0.id == .overdue })?.tasks.first?.id == "missed")
        #expect(groups.first(where: { $0.id == .today })?.tasks.first?.id == "tonight")
    }

    @Test func keepsAnAllDayTaskDueTodayOutOfOverdueUntilTheDayEnds() {
        let groups = groupTasks([Item(due: "2026-09-07", dueTime: nil)], at(2026, 9, 7, 23))
        #expect(groups[0].id == .today)
    }

    @Test func keepsUndatedWorkSeparateFromFarOffWork() {
        let groups = groupTasks([Item(id: "inbox", due: nil), Item(id: "far", due: "2027-01-01")], NOW)
        #expect(groups.first(where: { $0.id == .none })?.tasks.map(\.id) == ["inbox"])
        #expect(groups.first(where: { $0.id == .upcoming })?.tasks.map(\.id) == ["far"])
    }

    @Test func sortsAnExactTimeBeforeAllDayOnTheSameDay() {
        let groups = groupTasks([
            Item(id: "allday", due: "2026-09-09", dueTime: nil),
            Item(id: "nine", due: "2026-09-09", dueTime: "09:00"),
        ], NOW)
        #expect(groups[0].tasks.map(\.id) == ["nine", "allday"])
    }

    @Test func breaksDeadlineTiesByTitle() {
        let groups = groupTasks([
            Item(id: "z", title: "Zoology", due: "2026-09-09"),
            Item(id: "a", title: "Algebra", due: "2026-09-09"),
        ], NOW)
        #expect(groups[0].tasks.map(\.id) == ["a", "z"])
    }

    // MARK: filterTasks

    private let tasks = [
        Item(id: "a", courseID: c1, kindName: "assignment"),
        Item(id: "b", courseID: c2, kindName: "exam"),
        Item(id: "c", courseID: c2, kindName: "reminder"),
        Item(id: "d", courseID: nil, kindName: "assignment"),
    ]

    @Test func passesEverythingThroughByDefault() {
        #expect(filterTasks(tasks, .defaults, isArchived: { _ in false }).count == 4)
    }

    @Test func filtersBySubject() {
        let out = filterTasks(tasks, TaskFilters(subject: c2), isArchived: { _ in false })
        #expect(out.map(\.id) == ["b", "c"])
    }

    @Test func filtersByType() {
        let out = filterTasks(tasks, TaskFilters(kind: "assignment"), isArchived: { _ in false })
        #expect(out.map(\.id) == ["a", "d"])
    }

    @Test func showsWorkFromArchivedClassesByDefault() {
        let out = filterTasks(tasks, .defaults, isArchived: { $0 == c1 })
        #expect(out.map(\.id).contains("a"))
    }

    @Test func hidesArchivedWorkOnlyWhenAsked() {
        let out = filterTasks(tasks, TaskFilters(includeArchived: false), isArchived: { $0 == c1 })
        #expect(out.map(\.id) == ["b", "c", "d"])
    }

    @Test func neverHidesInboxWorkAsArchived() {
        let out = filterTasks(tasks, TaskFilters(includeArchived: false), isArchived: { _ in true })
        #expect(out.map(\.id).contains("d"))
    }

    // MARK: filter summaries

    @Test func countsWhatIsNarrowingTheList() {
        #expect(TaskFilters.defaults.activeCount == 0)
        #expect(TaskFilters(subject: c1, kind: "exam", includeArchived: false).activeCount == 3)
    }

    @Test func knowsWhenNothingIsFiltered() {
        #expect(TaskFilters.defaults.isDefault)
        #expect(!TaskFilters(kind: "exam").isDefault)
    }

    // MARK: normalizeViewPrefs

    @Test func fallsBackToDefaultsForAnythingUnreadable() {
        let p = normalizeViewPrefs(tab: nil, subject: nil, kind: nil, includeArchived: nil)
        #expect(p == TaskViewPrefs())
        let junk = normalizeViewPrefs(tab: "nope", subject: "", kind: "", includeArchived: nil)
        #expect(junk == TaskViewPrefs())
    }

    @Test func roundTripsARealPreference() {
        let p = normalizeViewPrefs(tab: "done", subject: c2.uuidString, kind: "exam", includeArchived: false)
        #expect(p == TaskViewPrefs(tab: .done,
                                   filters: TaskFilters(subject: c2, kind: "exam", includeArchived: false)))
    }

    @Test func treatsAnAbsentIncludeArchivedAsShown() {
        let p = normalizeViewPrefs(tab: "open", subject: c1.uuidString, kind: nil, includeArchived: nil)
        #expect(p.filters.includeArchived)
    }

    @Test func dropsAFilterValueItDoesNotRecognise() {
        let p = normalizeViewPrefs(tab: nil, subject: "5", kind: "homework", includeArchived: nil)
        #expect(p.filters.kind == nil)
        #expect(p.filters.subject == nil)
    }

    // MARK: dueLabel (lib/store.tsx)

    @Test func labelsEachDistance() {
        func label(_ due: String?, _ time: String? = nil) -> DueLabel {
            dueLabel(Deadline(date: due, time: time), NOW)
        }
        #expect(label(nil) == DueLabel(text: "No deadline", urgent: false))
        #expect(label("2026-09-06") == DueLabel(text: "Overdue", urgent: true))
        #expect(label("2026-09-07", "09:00") == DueLabel(text: "Overdue", urgent: true))
        #expect(label("2026-09-07") == DueLabel(text: "Due today", urgent: true))
        #expect(label("2026-09-08") == DueLabel(text: "Due tomorrow", urgent: true))
        #expect(label("2026-09-10") == DueLabel(text: "In 3 days", urgent: false))
        #expect(label("2026-09-14") == DueLabel(text: "In 1 week", urgent: false))
        #expect(label("2026-09-28") == DueLabel(text: "In 3 weeks", urgent: false))
    }

    // MARK: longDeadline (lib/store.tsx)

    @Test func spellsOutTheDayAndTime() {
        #expect(longDeadline(Deadline(date: "2026-09-07", time: nil)) == "Monday, Sep 7")
        #expect(longDeadline(Deadline(date: "2026-09-07", time: "14:30")) == "Monday, Sep 7 · 2:30 PM")
        #expect(longDeadline(Deadline(date: nil, time: nil)) == "No deadline")
    }
}
