// StudyTests.swift: the Swift twin of lib/study.test.ts, plus the phone's
// wall-clock run (D-62), the block-end alerts in StudyTimer.tsx's words, and
// its `clock` and `span` helpers. Cases marked "web:" are the web's own output
// (node 24, 2026-10-20).
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private func kinds(_ rounds: Int) -> [BlockKind] {
    var c = DEFAULT_POMODORO
    c.rounds = rounds
    return buildPlan(c).map(\.kind)
}

private func plan(rounds: Int) -> [StudyBlock] {
    var c = DEFAULT_POMODORO
    c.rounds = rounds
    return buildPlan(c)
}

/// A fixed starting moment, so every end time is exact.
private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

@Suite struct StudyTests {

    // MARK: buildPlan

    @Test func isASingleFocusBlockForOneRound() {
        #expect(plan(rounds: 1) == [StudyBlock(kind: .focus, minutes: 25)])
    }

    @Test func alternatesFocusAndBreak() {
        #expect(kinds(3) == [.focus, .rest, .focus, .rest, .focus])
    }

    @Test func neverEndsOnABreak() {
        for r in 1...8 { #expect(kinds(r).last == .focus) }
    }

    @Test func givesTheLongBreakAfterTheFourthFocusBlock() {
        let breaks = plan(rounds: 5).filter { $0.kind == .rest }
        #expect(breaks.map(\.minutes) == [5, 5, 5, 15])
        #expect(breaks.last?.long == true)
    }

    @Test func dropsTheLongBreakWhenTheFourthRoundIsTheLast() {
        let p = plan(rounds: 4)
        #expect(!p.contains(where: { $0.long }))
        #expect(p.count == 7)
    }

    @Test func runsTheFullLadderAtTheMaximumRoundCount() {
        let p = plan(rounds: 8)
        #expect(p.filter { $0.long }.count == 1)
        #expect(planMinutes(p) == 8 * 25 + 6 * 5 + 15)
        #expect(planMinutes(plan(rounds: 9)) == planMinutes(p))
    }

    // MARK: normalizeConfig

    @Test func aFreshConfigIsTheDefault() {
        #expect(normalizeConfig(PomodoroConfig()) == DEFAULT_POMODORO)
    }

    @Test func clampsRoundsAndBlockLengthsIntoRange() {
        #expect(normalizeConfig(PomodoroConfig(rounds: 99)).rounds == 8)
        #expect(normalizeConfig(PomodoroConfig(rounds: 0)).rounds == 1)
        #expect(normalizeConfig(PomodoroConfig(focus: 9999)).focus == 240)
        #expect(normalizeConfig(PomodoroConfig(shortBreak: 0)).shortBreak == 1)
        #expect(normalizeConfig(PomodoroConfig(longBreak: 600)).longBreak == 60)
    }

    /// The web rounds fractional input inside normalizeConfig; the phone's
    /// numbers are whole by then, so typed input goes through clampMinutes.
    @Test func roundsFractionalInputLikeMathRound() {
        #expect(clampMinutes(25.6, 1, 240) == 26)
        #expect(clampMinutes(25.5, 1, 240) == 26)   // web: Math.round(25.5) = 26
        #expect(clampMinutes(25.4, 1, 240) == 25)
        #expect(clampMinutes(0, 1, 240) == 1)
        #expect(clampMinutes(9999, 1, 240) == 240)
        #expect(clampMinutes(.nan, 1, 240) == 1)
    }

    // MARK: focusMinutesDone

    @Test func focusMinutesCountFocusOnlyAndSaturate() {
        let p = plan(rounds: 3)
        #expect(focusMinutesDone(p, 0) == 0)
        #expect(focusMinutesDone(p, 2) == 25)
        #expect(focusMinutesDone(p, 3) == 50)
        #expect(focusMinutesDone(p, p.count) == 75)
        #expect(focusMinutesDone(p, 999) == 75)
        #expect(focusMinutesDone(p, -5) == 0)
    }

    // MARK: plan readouts

    @Test func planReadouts() {
        #expect(planMinutes(plan(rounds: 4)) == 4 * 25 + 3 * 5)
        #expect(focusCount(plan(rounds: 4)) == 4)
        let p = plan(rounds: 3)
        #expect(p.indices.map { roundAt(p, $0) } == [1, 1, 2, 2, 3])
    }

    // MARK: singlePlan

    @Test func singlePlanIsOneClampedFocusBlock() {
        #expect(singlePlan(45) == [StudyBlock(kind: .focus, minutes: 45)])
        #expect(singlePlan(9999)[0].minutes == 240)
        #expect(singlePlan(0)[0].minutes == 1)
    }

    // MARK: clock and span (components/StudyTimer.tsx)

    @Test func clockAndSpanReadLikeTheWeb() {
        // web: clock(3671) "1:01:11", clock(125) "2:05", clock(0.2) "0:01",
        // clock(-3) "0:00", clock(1500) "25:00"
        #expect(studyClock(3671) == "1:01:11")
        #expect(studyClock(125) == "2:05")
        #expect(studyClock(0.2) == "0:01")
        #expect(studyClock(-3) == "0:00")
        #expect(studyClock(1500) == "25:00")
        // web: span(115) "1h 55m", span(60) "1h", span(25) "25 min", span(0) "0 min"
        #expect(studySpan(115) == "1h 55m")
        #expect(studySpan(60) == "1h")
        #expect(studySpan(25) == "25 min")
        #expect(studySpan(0) == "0 min")
    }

    // MARK: the run (D-62)

    @Test func everyBlockEndIsKnownFromTheStart() {
        let run = StudyRun(plan: plan(rounds: 2), now: t0)   // 25, 5, 25
        #expect(blockEnds(run) == [at(25), at(30), at(55)])
    }

    @Test func thePositionComesFromTheClockAlone() {
        let run = StudyRun(plan: plan(rounds: 2), now: t0)
        #expect(runPosition(run, at: at(10)) == RunPosition(index: 0, remaining: 15 * 60, finished: false))
        #expect(runPosition(run, at: at(27)) == RunPosition(index: 1, remaining: 3 * 60, finished: false))
        // A phone asleep from minute 10 to minute 40 wakes in the second focus block.
        #expect(runPosition(run, at: at(40)) == RunPosition(index: 2, remaining: 15 * 60, finished: false))
        #expect(runPosition(run, at: at(55)).finished)
        #expect(runPosition(run, at: at(500)) == RunPosition(index: 3, remaining: 0, finished: true))
    }

    @Test func pausingKeepsWhatWasLeftAndResumingShiftsEveryEnd() {
        let run = StudyRun(plan: plan(rounds: 2), now: t0)
        let paused = pausedRun(run, at: at(27))            // in the break, 3 min left
        #expect(paused.index == 1)
        #expect(paused.left == 3 * 60)
        var resumed = paused
        resumed.anchor = at(40)                           // 13 minutes later
        #expect(blockEnds(resumed) == [at(43), at(68)])
        #expect(runPosition(resumed, at: at(50)) == RunPosition(index: 2, remaining: 18 * 60, finished: false))
    }

    @Test func finishedFocusBlocksAreCountedOnceAtTheirRealEnd() {
        let run = StudyRun(plan: plan(rounds: 3), now: t0)   // 25, 5, 25, 5, 25
        // Asleep until minute 62: two focus blocks ended, at 25 and 55.
        let first = newlyFinished(run, from: 0, at: at(62))
        #expect(first.blocks == [FinishedFocus(index: 0, minutes: 25, endedAt: at(25)),
                                 FinishedFocus(index: 2, minutes: 25, endedAt: at(55))])
        // Four blocks are behind you: both focus blocks and both breaks.
        #expect(first.through == 4)
        // Asking again a moment later finds nothing new.
        #expect(newlyFinished(run, from: first.through, at: at(63)).blocks.isEmpty)
        // The end of the session brings the last one.
        let last = newlyFinished(run, from: first.through, at: at(200))
        #expect(last.blocks == [FinishedFocus(index: 4, minutes: 25, endedAt: at(85))])
        #expect(last.through == 5)
    }

    @Test func aResumedRunNeverRecountsTheBlocksBeforeIt() {
        let run = StudyRun(plan: plan(rounds: 2), now: t0)
        let done = newlyFinished(run, from: 0, at: at(27)).through   // 1: focus 0 counted
        var resumed = pausedRun(run, at: at(27))
        resumed.anchor = at(40)
        let next = newlyFinished(resumed, from: done, at: at(100))
        #expect(next.blocks == [FinishedFocus(index: 2, minutes: 25, endedAt: at(68))])
        #expect(next.through == 3)
    }

    @Test func aSingleBlockRunsAndFinishes() {
        let run = StudyRun(plan: singlePlan(45), now: t0)
        #expect(runPosition(run, at: at(44.5)).remaining == 30)
        let done = newlyFinished(run, from: 0, at: at(46))
        #expect(done.blocks == [FinishedFocus(index: 0, minutes: 45, endedAt: at(45))])
        #expect(runPosition(run, at: at(46)).finished)
    }

    // MARK: alerts (StudyTimer.tsx's showReminder calls)

    @Test func alertsSayWhatComesNextInTheWebsWords() {
        var c = DEFAULT_POMODORO
        c.rounds = 5
        let run = StudyRun(plan: buildPlan(c), now: t0)   // f b f b f b f B f
        let alerts = studyAlerts(run, title: "Essay", after: t0)
        #expect(alerts.count == 9)
        #expect(alerts[0] == StudyAlert(id: "study.0", at: at(25), title: "Break time",
                                        body: "5 minutes off. Stand up."))
        #expect(alerts[1] == StudyAlert(id: "study.1", at: at(30), title: "Round 2 of 5",
                                        body: "25 more minutes on \u{201C}Essay\u{201D}."))
        #expect(alerts[6].title == "Long break")
        #expect(alerts[6].body == "15 minutes off. Stand up.")
        // 5 x 25 + 3 x 5 + 15 = 155 minutes: "2h 35m".
        #expect(alerts[8] == StudyAlert(id: "study.8", at: at(155), title: "Session complete",
                                        body: "2h 35m on \u{201C}Essay\u{201D}. Nice work."))
    }

    @Test func alertsAlreadyBehindYouAreLeftOut() {
        let run = StudyRun(plan: plan(rounds: 2), now: t0)
        let alerts = studyAlerts(run, title: "Essay", after: at(26))
        #expect(alerts.map(\.id) == ["study.1", "study.2"])
        #expect(alerts.allSatisfy { $0.id.hasPrefix(studyAlertPrefix) })
    }
}
