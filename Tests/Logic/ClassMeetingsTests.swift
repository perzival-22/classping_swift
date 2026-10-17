// ClassMeetingsTests.swift: the Swift twin of lib/class-meetings.test.ts.
// Run: tools/logic-test.sh. Kelvin does not type this file.
//
// Ported: identity and keys, unscheduled subjects, and the rejection rules.
// Not ported here, and where they come back: the Supabase round trip (Phase 14,
// sync mapper), the calendar export (Phase 11), backups (Phase 11) and feed
// fingerprints (Phase 13). The web's "bad:id" case has no Swift twin, because
// a UUID can't hold a colon. The last three tests are extra, written from the
// code (meetingError and meetingSummary have no web test of their own).
import Foundation
import Testing
@testable import CPLogic

/// A stand-in class: just the fields Schedulable asks for.
private struct Subject: Schedulable {
    var id = UUID()
    var days: [Int]
    var startMin: Int
    var endMin: Int
    var room: String? = nil
    var additionalMeetings: [ClassMeeting] = []
}

/// The web test's "lab" meeting: Monday and Sunday, 2 PM to 4 PM, in Lab 3.
private let lab = ClassMeeting(days: [0, 6], start: 840, end: 960, room: "Lab 3")

/// The web test's subject: Biology on Mondays, 9 to 10, plus the lab.
private let subject = Subject(days: [0], startMin: 540, endMin: 600,
                              room: "Lecture hall", additionalMeetings: [lab])

@Suite struct ClassMeetingsTests {

    @Test func retainsSubjectIdentityWhileGivingSameDayMeetingsDistinctKeys() {
        let slots = expandClassMeetings([subject])
        #expect(slots.map { $0.course.id } == [subject.id, subject.id])
        #expect(slots.map(\.id) == [subject.id.uuidString,
                                    "\(subject.id.uuidString):\(lab.id.uuidString)"])
        #expect(slots[1].meeting.days == [0, 6])
        #expect(slots[1].meeting.start == 840)
        #expect(slots[1].meeting.room == "Lab 3")
        // No extra meetings: just the main one.
        var plain = subject
        plain.additionalMeetings = []
        #expect(classMeetings(plain).count == 1)
        #expect(classMeetings(plain)[0].id == primaryMeetingID)
    }

    @Test func treatsASubjectWithNoMeetingDaysAsUnscheduled() {
        let pending = Subject(days: [], startMin: 540, endMin: 600)
        #expect(isUnscheduled(pending))
        #expect(meetingSummary(pending) == "No set schedule yet")
        #expect(!isUnscheduled(subject))
        // Scheduled the moment any meeting has a day.
        let labOnly = Subject(days: [], startMin: 540, endMin: 600,
                              additionalMeetings: [ClassMeeting(days: [2], start: 540, end: 600)])
        #expect(!isUnscheduled(labOnly))
    }

    @Test func rejectsDuplicateAndReservedIdsUnsafeTimesInvalidDaysAndTooManySlots() {
        #expect(!validAdditionalMeetings([lab, lab]))
        // Each change on its own makes the lab invalid.
        let broken: [ClassMeeting] = [
            ClassMeeting(id: primaryMeetingID, days: [0, 6], start: 840, end: 960),
            ClassMeeting(days: [7], start: 840, end: 960),
            ClassMeeting(days: [0, 0], start: 840, end: 960),
            ClassMeeting(days: [0, 6], start: -1, end: 960),
            ClassMeeting(days: [0, 6], start: 840, end: 1440),
            ClassMeeting(days: [0, 6], start: 840, end: 840),
        ]
        for meeting in broken {
            #expect(!validAdditionalMeetings([meeting]))
        }
        // Twenty extra slots plus the main meeting is one too many; nineteen is fine.
        let twenty = (0..<20).map { _ in ClassMeeting(days: [0], start: 840, end: 960) }
        #expect(!validAdditionalMeetings(twenty))
        #expect(validAdditionalMeetings(Array(twenty.prefix(19))))
    }

    @Test func dropsADamagedExtraListAndKeepsTheMainMeeting() {
        var damaged = subject
        damaged.additionalMeetings = [lab, ClassMeeting(days: [9], start: 840, end: 960)]
        #expect(classMeetings(damaged).count == 1)
    }

    @Test func explainsTheFirstProblemWithAListOfMeetings() {
        let main = ClassMeeting(id: primaryMeetingID, days: [0], start: 540, end: 600)
        #expect(meetingError([]) == "Add between 1 and 20 meeting times.")
        #expect(meetingError(Array(repeating: main, count: 21)) == "Add between 1 and 20 meeting times.")
        let noDays = ClassMeeting(days: [], start: 600, end: 660)
        #expect(meetingError([main, noDays])
                == "Meeting 2: choose at least one day and an end time after the start time.")
        #expect(meetingError([main, main]) == "Meeting identifiers must be unique.")
        #expect(meetingError([main, lab]) == nil)
    }

    @Test func summarisesEveryMeetingOnOneLine() {
        #expect(meetingSummary(subject) == "Mon 09:00–10:00 · Lecture hall; Mon/Sun 14:00–16:00 · Lab 3")
        var labelled = subject
        labelled.room = ""                       // an empty room counts as none
        labelled.additionalMeetings = [ClassMeeting(days: [4], start: 840, end: 960, label: "Lab")]
        #expect(meetingSummary(labelled) == "Mon 09:00–10:00; Lab: Fri 14:00–16:00")
    }
}
