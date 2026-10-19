// PostClassTests.swift: Phase 7c. The web has no test file for
// `justEndedClass` or the prompt page's `nextClassToday`, so these pin the
// behaviour their code and comments describe. The notification routes are
// phone-only (the web routes by URL in sw.js).
// Run: tools/logic-test.sh. Kelvin does not type this file.

import Foundation
import Testing
@testable import CPLogic

/// A local date and time. 2026-09-14 is a Monday (day 0).
private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
    Calendar.current.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}

/// A stand-in class: just a timetable.
private struct Room: Schedulable {
    var id = UUID()
    var days: [Int]
    var startMin: Int
    var endMin: Int
    var room: String? = nil
    var additionalMeetings: [ClassMeeting] = []
}

@Suite struct JustEndedTests {
    private let calc = Room(days: [0, 2], startMin: 540, endMin: 600)   // Mon/Wed 9:00 to 10:00

    @Test func countsTheHalfHourAfterTheEndAndNoLonger() {
        #expect(justEnded([calc], now: at(2026, 9, 14, 9, 59)) == nil)          // still on
        #expect(justEnded([calc], now: at(2026, 9, 14, 10, 0))?.course.id == calc.id)
        #expect(justEnded([calc], now: at(2026, 9, 14, 10, 30))?.course.id == calc.id)
        #expect(justEnded([calc], now: at(2026, 9, 14, 10, 31)) == nil)         // window over
    }

    @Test func onlyCountsTodaysMeetings() {
        // Tuesday at 10:10: Calc met on Monday and meets again Wednesday.
        #expect(justEnded([calc], now: at(2026, 9, 15, 10, 10)) == nil)
    }

    @Test func backToBackTheLatestEndWins() {
        let lab = Room(days: [0], startMin: 600, endMin: 650)               // Mon 10:00 to 10:50
        #expect(justEnded([calc, lab], now: at(2026, 9, 14, 10, 55))?.course.id == lab.id)
        // A tie goes to the first in the list, like the web's stable sort.
        let twin = Room(days: [0], startMin: 550, endMin: 600)
        #expect(justEnded([calc, twin], now: at(2026, 9, 14, 10, 5))?.course.id == calc.id)
    }

    @Test func anExtraMeetingCountsAsItself() {
        let lab = ClassMeeting(days: [0], start: 840, end: 900, label: "Lab")    // Mon 2:00 to 3:00
        let chem = Room(days: [1], startMin: 540, endMin: 600, additionalMeetings: [lab])
        let slot = justEnded([chem], now: at(2026, 9, 14, 15, 10))
        #expect(slot?.meeting.id == lab.id)
        #expect(slot.map(meetingKey) == "\(chem.id.uuidString):\(lab.id.uuidString)")
    }

    @Test func nothingWithoutClasses() {
        #expect(justEnded([Room](), now: at(2026, 9, 14, 10, 0)) == nil)
    }
}

@Suite struct NextClassTodayTests {
    private let early = Room(days: [0], startMin: 540, endMin: 600)    // 9:00
    private let now10 = Room(days: [0], startMin: 600, endMin: 650)    // 10:00
    private let late = Room(days: [0], startMin: 780, endMin: 840)     // 1:00 PM
    private let mid = Room(days: [0], startMin: 660, endMin: 700)      // 11:00
    private let tuesday = Room(days: [1], startMin: 620, endMin: 680)  // Tue 10:20

    @Test func theSoonestStillToStartToday() {
        // At 10:00 the 10:00 class has started (the web asks start > now).
        let next = nextClassToday([early, now10, late, mid, tuesday], now: at(2026, 9, 14, 10, 0))
        #expect(next?.course.id == mid.id)
    }

    @Test func nilWhenTheDayIsDone() {
        #expect(nextClassToday([early, now10, mid, late], now: at(2026, 9, 14, 13, 0)) == nil)
        #expect(nextClassToday([tuesday], now: at(2026, 9, 14, 8, 0)) == nil)
    }
}

@Suite struct NotificationRouteTests {
    let course = UUID()
    let task = UUID()

    /// What 7a attaches to each notification: the kind, then the class and
    /// task ids as text, "" when there's none.
    private func info(_ kind: String, course: UUID? = nil, task: UUID? = nil) -> [AnyHashable: Any] {
        ["kind": kind, "course": course?.uuidString ?? "", "assignment": task?.uuidString ?? ""]
    }

    @Test func anAfterClassNudgeOpensThePromptForItsClass() {
        #expect(notificationRoute(info("post-class", course: course)) == .postClass(course))
        // No readable class: the prompt guesses from the clock, as /prompt does.
        #expect(notificationRoute(info("post-class")) == .postClass(nil))
    }

    @Test func taskRemindersOpenTheirTask() {
        #expect(notificationRoute(info("task-nag", task: task)) == .task(task))
        #expect(notificationRoute(info("task-lead", task: task)) == .task(task))
        #expect(notificationRoute(info("task-nag")) == .today)
    }

    @Test func classAlarmsAndAnythingElseOpenToday() {
        #expect(notificationRoute(info("class", course: course)) == .today)
        #expect(notificationRoute(info("something-new", task: task)) == .today)
        #expect(notificationRoute([:]) == .today)
        #expect(notificationRoute(["kind": 7, "assignment": task.uuidString]) == .today)
        #expect(notificationRoute(info("task-lead").merging(["assignment": "not-a-uuid"]) { $1 }) == .today)
    }
}
