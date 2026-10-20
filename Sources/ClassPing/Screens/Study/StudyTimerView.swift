//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Study/StudyTimerView.swift
//  Phase:   10a (the study timer)
//  Ports:   components/StudyTimer.tsx (the running, paused and finished
//           states, focus mode, and its `onFocusComplete` and
//           `onFinishTask` callbacks in app/tasks/[id]/page.tsx)
//
//  Summary: A study session for one assignment, in a sheet. Setup, then a
//           ring counting down each block, Pause and Stop, and a focus mode
//           that hides everything but the clock. Every block's end is worked out when you start, so
//           the session keeps time with the phone in your pocket: an alert
//           rings at each block's end, and each finished focus block is
//           recorded at the moment it ended.
//

import SwiftUI

struct StudyTimerView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The work being studied. A copy taken when the sheet opened; whether
    /// it's done is read live from the store.
    let assignment: Assignment

    /// Where the session is. An enum with a value in three of its cases: the
    /// run travels with the state it belongs to, so a paused session can't be
    /// missing its run, and setup can't have one.
    private enum Phase: Equatable {
        case setup
        case running(StudyRun)
        case paused(StudyRun)
        case done(StudyRun)
    }

    @State private var phase = Phase.setup
    // The setup choices, kept here so "Another session" starts from them.
    @State private var mode = StudySession.Mode.timer
    @State private var minutes = 25
    @State private var config = DEFAULT_POMODORO
    /// How many of the plan's blocks are behind you and dealt with.
    @State private var credited = 0
    /// Focus mode, the web's "zen": everything but the clock hidden.
    @State private var zen = false

    var body: some View {
        let accent = store.profile.accent

        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // `switch` on the phase: each case gets its own screen.
                    // `let run` takes the value out of the case to use it.
                    switch phase {
                    case .setup:
                        header("WORKING ON", assignment.title)
                        StudySetupView(mode: $mode, minutes: $minutes, config: $config,
                                       onStart: start)
                    case .running(let run):
                        // A clock redrawn twice a second; every number on it
                        // comes from the time, never from counting ticks.
                        TimelineView(.periodic(from: .now, by: 0.5)) { context in
                            live(run, at: context.date)
                        }
                    case .paused(let run):
                        face(run, RunPosition(index: run.index, remaining: run.left,
                                              finished: false), paused: true)
                    case .done(let run):
                        finished(run)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.canvas)
            .navigationTitle("Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // While a session runs, Stop ends it; Close is for before and after.
                if !isActive {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .tint(Theme.brand(accent))
            // Focus mode hides the bar along with everything else.
            .toolbar(zen ? .hidden : .visible, for: .navigationBar)
        }
        // Focus mode, laid over the whole sheet. An overlay rather than a
        // full-screen cover: a cover would make this screen "disappear",
        // and its `onDisappear` would cancel the alerts you need most then.
        .overlay {
            if zen { zenView }
        }
        // A swipe down can't throw away a running session by accident.
        .interactiveDismissDisabled(isActive)
        // Hand iOS this session's block-end alerts whenever it starts, pauses,
        // resumes, stops or ends. `.task(id:)` cancels the last call first.
        .task(id: phase) {
            await store.scheduleStudyAlerts(currentAlerts)
        }
        // Closing the sheet ends the session, so its alerts go too.
        .onDisappear {
            Task { await store.scheduleStudyAlerts([]) }
        }
    }

    // MARK: - State

    /// True while a session is running or paused.
    private var isActive: Bool {
        switch phase {
        case .running, .paused: true
        case .setup, .done: false
        }
    }

    /// The alerts for what's still ahead, while running; none otherwise.
    /// `if case` checks one case of an enum and takes its value out.
    private var currentAlerts: [StudyAlert] {
        if case .running(let run) = phase {
            return studyAlerts(run, title: assignment.title, after: .now)
        }
        return []
    }

    // MARK: - Actions

    /// Starts the plan the setup describes: the web's `startPlan`.
    private func start() {
        let plan = mode == .timer ? singlePlan(minutes) : buildPlan(config)
        credited = 0
        phase = .running(StudyRun(plan: plan, now: .now))
    }

    /// Records the focus blocks that ended since last time, each at its real
    /// end, and finishes the session after its last block. The web's
    /// `advance`, which runs once per block; this catches up on several at
    /// once after the phone slept.
    private func advance(_ run: StudyRun, at now: Date) {
        let result = newlyFinished(run, from: credited, at: now)
        for block in result.blocks {
            store.addStudySession(minutes: block.minutes, assignmentID: assignment.id,
                                  courseID: assignment.courseID, mode: mode,
                                  completedAt: block.endedAt)
        }
        credited = result.through
        if runPosition(run, at: now).finished {
            phase = .done(run)
            zen = false
        }
    }

    /// Stops the clock where it is. Whatever already finished is recorded first.
    private func pause(_ run: StudyRun) {
        let now = Date.now
        advance(run, at: now)
        if case .running = phase {
            phase = .paused(pausedRun(run, at: now))
        }
    }

    /// Starts the clock again from now: every later block moves along with it.
    private func resume(_ run: StudyRun) {
        var next = run
        next.anchor = .now
        phase = .running(next)
    }

    /// Back to setup. The web's `reset`; blocks already recorded stay recorded.
    private func stop() {
        phase = .setup
        zen = false
    }

    // MARK: - Pieces

    /// The small caps line and the title over the clock.
    private func header(_ label: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    /// A running session at one moment. `onChange(of:initial:)` (7c) notices
    /// each new block, including several at once after the phone slept, and
    /// records what finished.
    private func live(_ run: StudyRun, at now: Date) -> some View {
        let position = runPosition(run, at: now)
        return face(run, position, paused: false)
            .onChange(of: position.index, initial: true) {
                advance(run, at: now)
            }
    }

    /// The round dots, the ring with the time left, and the controls.
    private func face(_ run: StudyRun, _ position: RunPosition, paused: Bool) -> some View {
        let accent = store.profile.accent
        let index = min(position.index, run.plan.count - 1)
        let block = run.plan[index]
        let isBreak = block.kind == .rest
        let total = Double(block.minutes * 60)
        // How much of this block has gone, from 0 to 1.
        let gone = total > 0 ? 1 - min(1, position.remaining / total) : 0
        // Green for a break, your accent for work, as on the web.
        let color = isBreak ? Theme.good : Theme.brand(accent)
        let rounds = focusCount(run.plan)

        return VStack(spacing: 18) {
            header(isBreak ? "BREAK" : "WORKING ON", isBreak ? "Rest" : assignment.title)

            // One dot per round: done, now (wider), or still to come.
            if rounds > 1 {
                HStack(spacing: 6) {
                    ForEach(run.plan.indices.filter { run.plan[$0].kind == .focus }, id: \.self) { i in
                        Capsule()
                            .fill(i < index ? Theme.brand(accent) : i == index ? color : Theme.lineStrong)
                            .frame(width: i == index ? 20 : 8, height: 6)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Round \(roundAt(run.plan, index)) of \(rounds)")
            }

            // The ring: a full grey circle, and on top of it the same circle
            // trimmed to the share that's gone. `trim` draws only part of a
            // shape's outline; turning it -90° starts it at twelve o'clock.
            ZStack {
                Circle()
                    .stroke(Theme.surface2, lineWidth: 11)
                Circle()
                    .trim(from: 0, to: gone)
                    .stroke(color, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 6) {
                    Text(studyClock(position.remaining))
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text(paused ? "Paused" : isBreak ? "break" : "left")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 180, height: 180)
            .accessibilityElement(children: .combine)

            // Stop and Pause / Resume, then the way into focus mode.
            HStack(spacing: 10) {
                Button(action: stop) {
                    Text("Stop").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                Button {
                    if paused { resume(run) } else { pause(run) }
                } label: {
                    Text(paused ? "Resume" : "Pause").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Focus mode") { zen = true }
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 44)
        }
    }

    /// The end: what you did, then Mark it done, Another session or Close.
    private func finished(_ run: StudyRun) -> some View {
        let open = store.assignment(assignment.id)?.done == false
        return VStack(spacing: 14) {
            header("SESSION COMPLETE", assignment.title)
            Text("🎉").font(.system(size: 44))
            Text("\(studySpan(planMinutes(run.plan))) done")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.muted)
            // Only while the work is still open: the finished screen shouldn't
            // hand you a button that un-ticks it. (The web's XP line waits
            // for Phase 12.)
            if open {
                Button {
                    store.toggleAssignment(assignment.id)
                    dismiss()
                } label: {
                    Label("Mark it done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            Button { phase = .setup } label: {
                Text("Another session").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            Button("Close") { dismiss() }
                .frame(minHeight: 44)
        }
    }

    /// Focus mode: the round, what you're on, the time, a thin bar, and
    /// Pause / Resume and Exit. Nothing else. It only draws: the clock under
    /// it keeps running and recording, so finished blocks are counted once.
    @ViewBuilder
    private var zenView: some View {
        let accent = store.profile.accent
        ZStack {
            Theme.canvas.ignoresSafeArea()
            switch phase {
            case .running(let run):
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    zenFace(run, runPosition(run, at: context.date), paused: false, accent: accent)
                }
            case .paused(let run):
                zenFace(run, RunPosition(index: run.index, remaining: run.left, finished: false),
                        paused: true, accent: accent)
            case .setup, .done:
                // The session ended underneath: nothing to show, so leave.
                Color.clear.onAppear { zen = false }
            }
        }
        .tint(Theme.brand(accent))
    }

    private func zenFace(_ run: StudyRun, _ position: RunPosition, paused: Bool,
                         accent: Profile.Accent) -> some View {
        let index = min(position.index, run.plan.count - 1)
        let block = run.plan[index]
        let isBreak = block.kind == .rest
        let total = Double(block.minutes * 60)
        let gone = total > 0 ? 1 - min(1, position.remaining / total) : 0
        let color = isBreak ? Theme.good : Theme.brand(accent)
        let rounds = focusCount(run.plan)

        return VStack(spacing: 0) {
            Text(isBreak ? "BREAK" : rounds > 1 ? "ROUND \(roundAt(run.plan, index)) OF \(rounds)" : "FOCUS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
            Text(isBreak ? "Rest" : assignment.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .padding(.top, 10)
            Text(studyClock(position.remaining))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .padding(.top, 24)
            // The thin bar: a track, and the share that's gone laid over it.
            Capsule()
                .fill(Theme.surface2)
                .frame(width: 220, height: 3)
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: 220 * gone, height: 3)
                }
                .padding(.top, 32)
            HStack(spacing: 10) {
                Button(paused ? "Resume" : "Pause") {
                    if paused { resume(run) } else { pause(run) }
                }
                .buttonStyle(.bordered)
                Button("Exit") { zen = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 40)
        }
        .padding(.horizontal, 32)
    }
}
