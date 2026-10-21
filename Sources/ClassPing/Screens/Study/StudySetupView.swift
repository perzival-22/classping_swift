//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Study/StudySetupView.swift
//  Phase:   10a (the study timer), changed in 10b (the sound picker)
//  Ports:   the setup half of components/StudyTimer.tsx
//
//  Summary: The one decision before a study session: how long. One block
//           (15, 25, 45 or 60 minutes, or any number up to 240), or Pomodoro
//           (a focus length and 2, 3, 4 or 6 rounds, with breaks between).
//           Presets first, because "25 minutes" is a choice a stuck student
//           can make. Since 10b, a sound to study to: Silent, Rain, Deep
//           noise or Waves.
//

import SwiftUI

struct StudySetupView: View {
    @Environment(Store.self) private var store

    /// One block (`.timer`) or Pomodoro, owned by the timer screen.
    /// StudySession.Mode already names the two, so no new enum is needed.
    @Binding var mode: StudySession.Mode
    /// One block's length, in minutes.
    @Binding var minutes: Int
    /// Pomodoro's focus length and rounds.
    @Binding var config: PomodoroConfig
    /// NEW in Phase 10b: the sound for the session, or nil for silence.
    @Binding var ambience: AmbienceID?
    /// Starts the session the setup describes.
    let onStart: () -> Void

    /// The "Or set" field's text, kept as typed so a half-typed number isn't
    /// overwritten. A preset tap writes its number in here too.
    @State private var typed = ""
    @FocusState private var typing: Bool

    /// The web's `PRESETS` and `ROUND_CHOICES`.
    private let presets = [15, 25, 45, 60]
    private let roundChoices = [2, 3, 4, 6]

    var body: some View {
        let accent = store.profile.accent
        // What Start would run: the web's `previewPlan`.
        let preview = mode == .timer ? singlePlan(minutes) : buildPlan(config)

        VStack(alignment: .leading, spacing: 14) {
            // One block is the default; Pomodoro is a method you opt into.
            Picker("Mode", selection: $mode) {
                Text("One block").tag(StudySession.Mode.timer)
                Text("Pomodoro").tag(StudySession.Mode.pomodoro)
            }
            .pickerStyle(.segmented)

            if mode == .timer {
                chipRow(presets, selected: minutes, unit: "min") { p in
                    minutes = p
                    typed = "\(p)"
                }
                // Any length from 1 to 240. `clampMinutes` rounds the way
                // the web's input does, and keeps it in range.
                HStack(spacing: 10) {
                    Text("OR SET")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Theme.faint)
                    TextField("Minutes", text: $typed)
                        .keyboardType(.numberPad)
                        .focused($typing)
                        .inputField(accent)
                        .accessibilityLabel("Minutes")
                    Text("min").foregroundStyle(Theme.muted)
                }
                .onChange(of: typed) { _, text in
                    if let value = Double(text) {
                        minutes = clampMinutes(value, 1, MAX_BLOCK_MINUTES)
                    }
                }
            } else {
                label("FOCUS BLOCK")
                chipRow(presets, selected: config.focus, unit: "min") { config.focus = $0 }
                label("ROUNDS")
                chipRow(roundChoices, selected: config.rounds, unit: nil) { config.rounds = $0 }
                // "4 × 25 min, 5 min breaks, 1h 55m in all"
                Text("\(config.rounds) \u{00D7} \(config.focus) min, \(config.shortBreak) min breaks, \(studySpan(planMinutes(preview))) in all")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }

            // NEW in Phase 10b: the sound, made on the phone, so the list
            // costs nothing to ship. Tapping the chosen one again is Silent.
            label("SOUND")
            HStack(spacing: 10) {
                soundChip("Silent", on: ambience == nil, quiet: true) { ambience = nil }
                ForEach(AMBIENCES, id: \.id) { sound in
                    soundChip(sound.label, on: ambience == sound.id, quiet: false) {
                        ambience = ambience == sound.id ? nil : sound.id
                    }
                    .accessibilityHint(sound.hint)
                }
            }

            Button(action: onStart) {
                Text(mode == .timer ? "Start \(minutes) minutes" : "Start \(config.rounds) rounds")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
        // Start from whatever length the screen holds.
        .onAppear { typed = "\(minutes)" }
        // Swipe down or tap Done to put the number pad away (D-54).
        .keyboardDismissable { typing = false }
    }

    /// A small caps label over a row of chips.
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1)
            .foregroundStyle(Theme.faint)
    }

    /// Four chips in a row, the chosen one filled with your accent. `unit`
    /// is the small word under each number ("min"), or nil for none.
    private func chipRow(_ values: [Int], selected: Int, unit: String?,
                         pick: @escaping (Int) -> Void) -> some View {
        let accent = store.profile.accent
        return HStack(spacing: 10) {
            ForEach(values, id: \.self) { value in
                let on = value == selected
                Button { pick(value) } label: {
                    VStack(spacing: 2) {
                        Text("\(value)").font(.system(size: 18, weight: .bold))
                        if let unit {
                            Text(unit).font(.system(size: 10.5, weight: .medium)).opacity(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(on ? Color.white : Theme.muted)
                    .background(on ? Theme.brand(accent) : Theme.surface2,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(unit.map { "\(value) \($0 == "min" ? "minutes" : $0)" } ?? "\(value) rounds")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    // NEW in Phase 10b
    /// One sound chip. A chosen sound is filled with your accent; Silent,
    /// when chosen, just darkens, as on the web.
    private func soundChip(_ title: String, on: Bool, quiet: Bool,
                           pick: @escaping () -> Void) -> some View {
        let accent = store.profile.accent
        let fill = on ? (quiet ? Theme.lineStrong : Theme.brand(accent)) : Theme.surface2
        let ink = on ? (quiet ? Theme.ink : Color.white) : Theme.muted
        return Button(action: pick) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(ink)
                .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
