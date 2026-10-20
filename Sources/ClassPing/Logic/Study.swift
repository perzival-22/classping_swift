//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Study.swift
//  Phase:   10a (the study timer)
//  Ports:   lib/study.ts (blocks, Pomodoro plans, focus minutes), and the
//           `clock` and `span` helpers and block-end messages of
//           components/StudyTimer.tsx
//
//  Summary: What a study session is made of, and where a running one stands.
//           A plain timer is a plan of one focus block; Pomodoro alternates
//           focus and breaks. A running session is a plan plus one moment it
//           was timed from, so every block's end is known in advance: the
//           phone can sleep through a block and the count is still right.
//

import Foundation

/// What a block is for. The web calls them "focus" and "break"; `break` is a
/// Swift keyword, so here the second one is `rest`. On screen it's "Break".
enum BlockKind: String, Equatable, Sendable {
    case focus, rest
}

/// One timed stretch of a session. `StudyBlock` in lib/study.ts.
struct StudyBlock: Equatable, Sendable {
    var kind: BlockKind
    var minutes: Int
    /// True for the longer break earned after a run of focus blocks.
    var long = false
}

/// The four numbers a Pomodoro session is built from. `PomodoroConfig`.
/// The defaults are the classic 25 / 5 / 15, four rounds.
struct PomodoroConfig: Equatable, Sendable {
    /// Minutes of work per focus block.
    var focus = 25
    var shortBreak = 5
    var longBreak = 15
    /// How many focus blocks the whole session has.
    var rounds = 4
}

/// The web's `DEFAULT_POMODORO`: what a fresh `PomodoroConfig()` already is.
let DEFAULT_POMODORO = PomodoroConfig()
/// A long break replaces the short one after this many focus blocks.
let ROUNDS_PER_LONG_BREAK = 4
let MAX_ROUNDS = 8
/// Matches the single-block ceiling: a "focus block" of four hours isn't one.
let MAX_BLOCK_MINUTES = 240

/// A typed number of minutes, rounded and kept between `lo` and `hi`. The
/// web's `clamp`, with JavaScript's `Math.round` (a half rounds up: 25.5 is
/// 26), which is `floor(n + 0.5)`.
func clampMinutes(_ n: Double, _ lo: Int, _ hi: Int) -> Int {
    guard n.isFinite else { return lo }
    let rounded = (n + 0.5).rounded(.down)
    return Int(min(Double(hi), max(Double(lo), rounded)))
}

/// Every number of a config put back in range. `normalizeConfig` on the web.
func normalizeConfig(_ c: PomodoroConfig) -> PomodoroConfig {
    PomodoroConfig(focus: min(MAX_BLOCK_MINUTES, max(1, c.focus)),
                   shortBreak: min(60, max(1, c.shortBreak)),
                   longBreak: min(60, max(1, c.longBreak)),
                   rounds: min(MAX_ROUNDS, max(1, c.rounds)))
}

/// A config expanded into the blocks to run, in order. `buildPlan`.
/// No break at the end: the session ends on the work. The long break comes
/// after every fourth focus block, but only when more work follows.
func buildPlan(_ config: PomodoroConfig) -> [StudyBlock] {
    let c = normalizeConfig(config)
    var plan: [StudyBlock] = []
    for round in 1...c.rounds {
        plan.append(StudyBlock(kind: .focus, minutes: c.focus))
        // A break only between rounds, so the last round is never followed by one.
        if round < c.rounds {
            let long = round % ROUNDS_PER_LONG_BREAK == 0
            plan.append(StudyBlock(kind: .rest, minutes: long ? c.longBreak : c.shortBreak,
                                   long: long))
        }
    }
    return plan
}

/// A single timed block, so both modes run the same code. `singlePlan`.
func singlePlan(_ minutes: Int) -> [StudyBlock] {
    [StudyBlock(kind: .focus, minutes: min(MAX_BLOCK_MINUTES, max(1, minutes)))]
}

/// Minutes of focus in the first `count` blocks. `focusMinutesDone`.
/// Breaks don't count: resting is part of the method, not the work.
func focusMinutesDone(_ plan: [StudyBlock], _ count: Int) -> Int {
    plan.prefix(max(0, min(count, plan.count)))
        .filter { $0.kind == .focus }
        .reduce(0) { $0 + $1.minutes }
}

/// The whole plan's length, breaks included. `planMinutes`.
func planMinutes(_ plan: [StudyBlock]) -> Int {
    plan.reduce(0) { $0 + $1.minutes }
}

/// How many focus blocks the plan has, for "Round 2 of 4". `focusCount`.
func focusCount(_ plan: [StudyBlock]) -> Int {
    plan.filter { $0.kind == .focus }.count
}

/// Which round block `index` belongs to, counting from 1. A break reports the
/// round it follows. `roundAt`.
func roundAt(_ plan: [StudyBlock], _ index: Int) -> Int {
    plan.prefix(max(0, min(index + 1, plan.count))).filter { $0.kind == .focus }.count
}

/// 3671 seconds -> "1:01:11", 125 -> "2:05". The web's `clock`: partial
/// seconds round up, so the display never shows 0:00 while time is left.
func studyClock(_ seconds: Double) -> String {
    let s = max(0, Int(seconds.rounded(.up)))
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
}

/// 115 minutes -> "1h 55m", 60 -> "1h", 25 -> "25 min". The web's `span`.
func studySpan(_ minutes: Int) -> String {
    let h = minutes / 60, m = minutes % 60
    if h == 0 { return "\(m) min" }
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}

// MARK: - A running session (the phone's own)

/// A running or paused session: the plan, the block that was running at
/// `anchor`, and how much of that block was left then. Every later block
/// follows straight on, so each block's end is known from these four values.
/// The web keeps only the current block's end and starts the next block when
/// it notices the old one ended, which a sleeping phone notices late (D-62).
struct StudyRun: Equatable, Sendable {
    var plan: [StudyBlock]
    var index: Int
    var anchor: Date
    /// Seconds of block `index` still to go at `anchor`.
    var left: Double

    /// A fresh run: the first block, all of it, from `now`.
    init(plan: [StudyBlock], now: Date) {
        self.plan = plan
        index = 0
        anchor = now
        left = Double((plan.first?.minutes ?? 1) * 60)
    }

    init(plan: [StudyBlock], index: Int, anchor: Date, left: Double) {
        self.plan = plan
        self.index = index
        self.anchor = anchor
        self.left = left
    }
}

/// Where a run stands at one moment: which block, and how much of it is left.
struct RunPosition: Equatable, Sendable {
    var index: Int
    /// Seconds left in block `index`. Zero once finished.
    var remaining: Double
    /// True when the last block has ended.
    var finished: Bool
}

/// When each block from `run.index` on ends, in order.
func blockEnds(_ run: StudyRun) -> [Date] {
    // A run past its last block has nothing left to end.
    guard run.index >= 0, run.index < run.plan.count else { return [] }
    var ends: [Date] = []
    var end = run.anchor.addingTimeInterval(run.left)
    for i in run.index..<run.plan.count {
        if i > run.index { end = end.addingTimeInterval(Double(run.plan[i].minutes * 60)) }
        ends.append(end)
    }
    return ends
}

/// The block running at `now`, and its time left, worked out from the clock
/// alone. However long the phone slept, the answer is where the session
/// would have got to.
func runPosition(_ run: StudyRun, at now: Date) -> RunPosition {
    let ends = blockEnds(run)
    // The first block whose end is still ahead is the one running now.
    if let k = ends.firstIndex(where: { $0 > now }) {
        return RunPosition(index: run.index + k, remaining: ends[k].timeIntervalSince(now),
                           finished: false)
    }
    return RunPosition(index: run.plan.count, remaining: 0, finished: true)
}

/// The same session, stopped at `now`: the current block and what's left of
/// it, ready to start counting again from whenever you resume.
func pausedRun(_ run: StudyRun, at now: Date) -> StudyRun {
    let p = runPosition(run, at: now)
    return StudyRun(plan: run.plan, index: min(p.index, run.plan.count - 1),
                    anchor: now, left: p.remaining)
}

/// One focus block that has run to its end.
struct FinishedFocus: Equatable, Sendable {
    var index: Int
    var minutes: Int
    var endedAt: Date
}

/// The focus blocks that ended since block `done`, and the new `done`: how
/// many blocks are now behind you. The timer calls this as the clock moves
/// and records each block once, at the moment it really ended. (The web
/// records a block when it notices, with "now" as its time.)
func newlyFinished(_ run: StudyRun, from done: Int, at now: Date)
    -> (blocks: [FinishedFocus], through: Int) {
    let ends = blockEnds(run)
    let p = runPosition(run, at: now)
    // Blocks before `run.index` were dealt with before this run was timed.
    let start = max(done, run.index)
    var blocks: [FinishedFocus] = []
    if start < p.index {
        for i in start..<p.index where run.plan[i].kind == .focus {
            blocks.append(FinishedFocus(index: i, minutes: run.plan[i].minutes,
                                        endedAt: ends[i - run.index]))
        }
    }
    return (blocks, max(done, p.index))
}

/// A notification the phone should show when a block ends.
struct StudyAlert: Equatable, Sendable {
    var id: String
    var at: Date
    var title: String
    var body: String
}

/// The id prefix of every study alert, so the reminder sync can leave them be.
let studyAlertPrefix = "study."

/// What to say at the end of each block still ahead of `now`, in the web's
/// words (its `showReminder` calls in StudyTimer's `advance`): the next
/// block, or the end of the session.
func studyAlerts(_ run: StudyRun, title: String, after now: Date) -> [StudyAlert] {
    let ends = blockEnds(run)
    let rounds = focusCount(run.plan)
    var alerts: [StudyAlert] = []
    for (k, end) in ends.enumerated() where end > now {
        let i = run.index + k
        let next = i + 1
        if next >= run.plan.count {
            alerts.append(StudyAlert(id: "\(studyAlertPrefix)\(i)", at: end,
                                     title: "Session complete",
                                     body: "\(studySpan(planMinutes(run.plan))) on \u{201C}\(title)\u{201D}. Nice work."))
        } else if run.plan[next].kind == .rest {
            alerts.append(StudyAlert(id: "\(studyAlertPrefix)\(i)", at: end,
                                     title: run.plan[next].long ? "Long break" : "Break time",
                                     body: "\(run.plan[next].minutes) minutes off. Stand up."))
        } else {
            alerts.append(StudyAlert(id: "\(studyAlertPrefix)\(i)", at: end,
                                     title: "Round \(roundAt(run.plan, next)) of \(rounds)",
                                     body: "\(run.plan[next].minutes) more minutes on \u{201C}\(title)\u{201D}."))
        }
    }
    return alerts
}
